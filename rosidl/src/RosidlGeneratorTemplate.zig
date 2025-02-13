const std = @import("std");
const RosidlGenerator = @import("RosidlGenerator.zig");
const zigros = @import("../../zigros/zigros.zig");

const CompileArgs = zigros.CompileArgs;

fn pascalToSnake(allocator: std.mem.Allocator, in: []const u8) std.mem.Allocator.Error![]const u8 {
    var out = std.ArrayList(u8).init(allocator);
    var prev_is_lower = false;
    if (in.len == 0) return "";

    try out.append(std.ascii.toLower(in[0]));

    const isLower = std.ascii.isLower;
    const isUpper = std.ascii.isUpper;
    const isDigit = std.ascii.isDigit;

    if (in.len > 2) {
        for (in[0 .. in.len - 2], in[1 .. in.len - 1], in[2..]) |previous, current, next| {
            if ((isLower(previous) and isUpper(current)) or
                (isUpper(current) and isLower(next)) or
                (isDigit(previous) and isUpper(current)))
            {
                try out.append('_');
                prev_is_lower = false;
            }
            try out.append(std.ascii.toLower(current));
        }

        // Boundary condition - Handle the checks on the last character
        // (the 'previous' and 'current' checks, but after 'next' is out of bounds)
        const previous = in[in.len - 2];
        const current = in[in.len - 1];
        if (isDigit(previous) and isUpper(current) or isLower(previous) and isUpper(current)) {
            try out.append('_');
        }

        try out.append(std.ascii.toLower(in[in.len - 1]));
    } else if (in.len == 2) {
        try out.append(std.ascii.toLower(in[1]));
    }

    return out.toOwnedSlice();
}

test pascalToSnake {
    var allocator = std.testing.allocator;

    const empty_string = try pascalToSnake(allocator, "");
    defer allocator.free(empty_string);
    try std.testing.expectEqualSlices(u8, "", empty_string);

    const single = try pascalToSnake(allocator, "A");
    defer allocator.free(single);
    try std.testing.expectEqualSlices(u8, "a", single);

    const double = try pascalToSnake(allocator, "Ab");
    defer allocator.free(double);
    try std.testing.expectEqualSlices(u8, "ab", double);

    const double2 = try pascalToSnake(allocator, "AB");
    defer allocator.free(double2);
    try std.testing.expectEqualSlices(u8, "ab", double2);

    const double3 = try pascalToSnake(allocator, "aB");
    defer allocator.free(double3);
    try std.testing.expectEqualSlices(u8, "ab", double3);

    const triple = try pascalToSnake(allocator, "AbC");
    defer allocator.free(triple);
    try std.testing.expectEqualSlices(u8, "ab_c", triple);

    const multi = try pascalToSnake(allocator, "TestPascal42");
    defer allocator.free(multi);
    try std.testing.expectEqualSlices(u8, "test_pascal42", multi);

    const all_upper = try pascalToSnake(allocator, "GID");
    defer allocator.free(all_upper);
    try std.testing.expectEqualSlices(u8, "gid", all_upper);

    const leading_upper = try pascalToSnake(allocator, "GPSFix");
    defer allocator.free(leading_upper);
    try std.testing.expectEqualSlices(u8, "gps_fix", leading_upper);

    const trailing_upper = try pascalToSnake(allocator, "FileUUID");
    defer allocator.free(trailing_upper);
    try std.testing.expectEqualSlices(u8, "file_uuid", trailing_upper);

    const mid_upper = try pascalToSnake(allocator, "FileUUIDTest");
    defer allocator.free(mid_upper);
    try std.testing.expectEqualSlices(u8, "file_uuid_test", mid_upper);

    const a_bit_of_everything = try pascalToSnake(allocator, "File42GPS7T3st6Wow");
    defer allocator.free(a_bit_of_everything);
    try std.testing.expectEqualSlices(u8, "file42_gps7_t3st6_wow", a_bit_of_everything);

    const bug_pose2d = try pascalToSnake(allocator, "Pose2D");
    defer allocator.free(bug_pose2d);
    try std.testing.expectEqualSlices(u8, "pose2_d", bug_pose2d);
}

pub const CodeType = enum {
    c,
    cpp,
    header_only,
};

pub const VisibilityControlType = enum {
    h,
    hpp,
};

// source template must accept three strings in the order "package", "type (msg/srv/action)", "name"
pub fn CodeGenerator(
    comptime code_type: CodeType,
    comptime visibility_control: ?VisibilityControlType,
    comptime source_templates: []const []const u8,
) type {
    return struct {
        const Self = @This();

        generator: *std.Build.Step.Run,
        generator_output: std.Build.LazyPath,
        package_name: []const u8,
        artifact: switch (code_type) {
            .c, .cpp => *std.Build.Step.Compile,
            .header_only => *std.Build.Step.WriteFile,
        },
        visibility_control_header: if (visibility_control) |_| *std.Build.Step.ConfigHeader else void,

        const Libraries = union(enum) {
            lib: *std.Build.Step.Compile,
            header_only: std.Build.LazyPath,
        };

        pub fn create(
            b: *std.Build,
            package_name: []const u8,
            compile_args: CompileArgs,
            generator_name: []const u8,
            generator_root: std.Build.LazyPath,
            deps: RosidlGenerator.Deps,
            build_deps: RosidlGenerator.BuildDeps,
            link_libs: ?[]const Libraries,
            additional_python_paths: ?[]const std.Build.LazyPath,
        ) *Self {
            const to_return = b.allocator.create(Self) catch @panic("OOM");
            to_return.generator = b.addRunArtifact(build_deps.code_generator);

            to_return.generator_output = to_return.generator.addPrefixedOutputDirectoryArg("-O", std.fmt.allocPrint(
                b.allocator,
                "{s}_{s}_generator_output",
                .{ package_name, generator_name },
            ) catch @panic("OOM")); // use generator name and package name for uniquness

            to_return.package_name = b.dupe(package_name);
            const package_name_upper = b.dupe(package_name);
            _ = std.ascii.upperString(package_name_upper, package_name_upper);

            const artifact_name = std.fmt.allocPrint(
                b.allocator,
                "{s}__{s}",
                .{ package_name, generator_name },
            ) catch @panic("OOM");

            var python_paths = std.ArrayList(std.Build.LazyPath).init(b.allocator);
            defer python_paths.deinit();

            python_paths.appendSlice(&.{
                build_deps.rosidl_parser,
                build_deps.rosidl_pycommon,
                build_deps.rosidl_generator_type_description,
                generator_root,
            }) catch @panic("OOM");

            if (additional_python_paths) |paths| {
                python_paths.appendSlice(paths) catch @panic("OOM");
            }

            for (python_paths.items) |path| {
                to_return.generator.addPrefixedDirectoryArg("-P", path);
            }

            switch (build_deps.python) {
                .system => |python| {
                    const arg = std.fmt.allocPrint(b.allocator, "-B{s}", .{python}) catch @panic("OOM");
                    defer b.allocator.free(arg);
                    to_return.generator.addArg(arg);
                },
                .build => |python| {
                    to_return.generator.addPrefixedDirectoryArg(
                        "-P",
                        build_deps.empy orelse
                            @panic("Build python specified but empy dependency not provided."),
                    );
                    to_return.generator.addPrefixedDirectoryArg(
                        "-P",
                        build_deps.lark orelse
                            @panic("Build python specified but lark dependency not provided."),
                    );
                    to_return.generator.addPrefixedFileArg("-B", python.getEmittedBin());
                },
            }

            to_return.generator.addPrefixedFileArg(
                "-X",
                generator_root.path(b, std.fmt.allocPrint(
                    b.allocator,
                    "bin/{s}",
                    .{generator_name},
                ) catch @panic("OOM")),
            );

            to_return.generator.addArg(std.fmt.allocPrint(
                b.allocator,
                "-N{s}",
                .{package_name},
            ) catch @panic("OOM"));

            to_return.generator.addPrefixedDirectoryArg(
                "-T",
                generator_root.path(b, "resource"),
            );

            to_return.generator.addArg(std.fmt.allocPrint(
                b.allocator,
                "-G{s}",
                .{generator_name},
            ) catch @panic("OOM"));

            if (visibility_control) |control_type| {
                to_return.visibility_control_header = b.addConfigHeader(
                    .{ .style = .{
                        .cmake = generator_root
                            .path(
                            b,
                            std.fmt.allocPrint(
                                b.allocator,
                                "resource/{s}__visibility_control.{s}.in",
                                .{ generator_name, @tagName(control_type) },
                            ) catch @panic("OOM"),
                        ),
                    }, .include_path = std.fmt.allocPrint(
                        b.allocator,
                        "{s}/msg/{s}__visibility_control.{s}",
                        .{ package_name, generator_name, @tagName(control_type) },
                    ) catch @panic("OOM") },
                    .{ .PROJECT_NAME = package_name, .PROJECT_NAME_UPPER = package_name_upper },
                );

                // TODO this feels like a bug? the visibility control header should automatically depend on the lazy path if its a generated path?
                generator_root.addStepDependencies(&to_return.visibility_control_header.step);
            }

            switch (code_type) {
                .c, .cpp => {
                    to_return.artifact = std.Build.Step.Compile.create(b, .{
                        .root_module = .{
                            .target = compile_args.target,
                            .optimize = compile_args.optimize,
                            .pic = if (compile_args.linkage == .dynamic) true else null,
                        },
                        .name = artifact_name,
                        .kind = .lib,
                        .linkage = compile_args.linkage,
                    });

                    if (compile_args.optimize == .ReleaseSmall and compile_args.linkage == .static) {
                        to_return.artifact.link_function_sections = true;
                        to_return.artifact.link_data_sections = true;
                    }

                    to_return.artifact.addIncludePath(deps.rosidl_typesupport_interface);
                    if (link_libs) |libs| for (libs) |lib| switch (lib) {
                        .lib => |l| to_return.artifact.linkLibrary(l),
                        .header_only => |h| to_return.artifact.addIncludePath(h),
                    };
                    to_return.artifact.linkLibrary(deps.rcutils);
                    to_return.artifact.addIncludePath(to_return.generator_output);
                    to_return.artifact.installHeadersDirectory(
                        to_return.generator_output,
                        "",
                        .{ .include_extensions = &.{ ".h", ".hpp" } },
                    );
                    if (visibility_control) |_| {
                        to_return.artifact.addConfigHeader(to_return.visibility_control_header);
                        to_return.artifact.installConfigHeader(to_return.visibility_control_header);
                    }
                },
                .header_only => {
                    to_return.artifact = b.addNamedWriteFiles(std.fmt.allocPrint(
                        b.allocator,
                        "{s}__{s}",
                        .{ package_name, generator_name },
                    ) catch @panic("OOM"));
                    _ = to_return.artifact.addCopyDirectory(
                        to_return.generator_output.path(b, package_name), // This is a work around for the CPP generator which seems to include the package name automatically where the c generator did not. Other generators may or may not require this extra dir, we'll see
                        package_name,
                        .{ .include_extensions = &.{ ".h", ".hpp" } },
                    );
                    if (visibility_control) |_| {
                        _ = to_return.artifact.addCopyFile(
                            to_return.visibility_control_header.getOutput(),
                            to_return.visibility_control_header.include_path,
                        );
                    }
                },
            }

            return to_return;
        }

        pub fn addInterface(self: *Self, path: std.Build.LazyPath, interface: []const u8) void {
            self.generator.addPrefixedDirectoryArg(
                "-I",
                path.path(self.generator.step.owner, interface),
            );
            self.addInterfaceFiles(interface);
        }

        pub fn addIdlTuple(
            self: *Self,
            name: []const u8,
            path: std.Build.LazyPath,
        ) void {
            self.generator.addPrefixedDirectoryArg(
                std.fmt.allocPrint(
                    self.generator.step.owner.allocator,
                    "-D{s}:",
                    .{name},
                ) catch @panic("OOM"),
                path,
            );
        }

        pub fn addTypeDescription(
            self: *Self,
            name: []const u8,
            path: std.Build.LazyPath,
        ) void {
            self.generator.addPrefixedDirectoryArg(
                std.fmt.allocPrint(
                    self.generator.step.owner.allocator,
                    "-Y{s}:",
                    .{name},
                ) catch @panic("OOM"),
                path,
            );
        }

        pub fn addInterfaceFiles(self: *Self, interface: []const u8) void {
            var arena_allocator = std.heap.ArenaAllocator.init(self.generator.step.owner.allocator);
            defer arena_allocator.deinit();
            const arena = arena_allocator.allocator();

            switch (code_type) {
                .c, .cpp => {
                    var c_files = std.ArrayListUnmanaged([]u8){};

                    var it = std.mem.tokenizeAny(u8, interface, "/.");
                    var suffix: []const u8 = "";
                    var base_in: ?[]const u8 = null;
                    // second last token should be our base file
                    while (it.next()) |token| {
                        base_in = suffix;
                        suffix = token;
                    }
                    const base = pascalToSnake(
                        arena,
                        base_in orelse @panic("Bad input file"),
                    ) catch @panic("OOM");
                    inline for (source_templates) |template| {
                        c_files.append(arena, std.fmt.allocPrint(
                            arena,
                            template,
                            .{ self.package_name, suffix, base },
                        ) catch @panic("OOM")) catch @panic("OOM");
                    }

                    switch (code_type) {
                        .c => {
                            self.artifact.addCSourceFiles(.{
                                .root = self.generator_output,
                                .files = c_files.items,
                                .flags = if (visibility_control != null) &.{
                                    "-fvisibility=hidden",
                                } else &.{},
                            });
                            self.artifact.linkLibC();
                        },
                        .cpp => {
                            self.artifact.addCSourceFiles(.{
                                .root = self.generator_output,
                                .files = c_files.items,
                                .flags = if (visibility_control != null) &.{
                                    "--std=c++17",
                                    "-fvisibility=hidden",
                                    "-fvisibility-inlines-hidden",
                                } else &.{
                                    "--std=c++17",
                                },
                            });
                            self.artifact.linkLibCpp();
                        },
                        .header_only => {},
                    }
                },
                .header_only => {},
            }
        }
    };
}
