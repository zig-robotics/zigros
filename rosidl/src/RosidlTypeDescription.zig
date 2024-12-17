const RosidlTypeDescription = @This();

const std = @import("std");
const RosidlGenerator = @import("RosidlGenerator.zig");

generator: *std.Build.Step.Run,
output: std.Build.LazyPath,

pub fn create(b: *std.Build, build_deps: RosidlGenerator.BuildDeps, package_name: []const u8) *RosidlTypeDescription {
    const to_return = b.allocator.create(RosidlTypeDescription) catch @panic("OOM");
    to_return.generator = b.addRunArtifact(
        build_deps.type_description_generator,
    );

    to_return.output = to_return.generator.addPrefixedOutputDirectoryArg("-O", std.fmt.allocPrint(
        b.allocator,
        "{s}_rosidl_generator_type_description_output",
        .{package_name},
    ) catch @panic("OOM")); // use generator name and package name for uniquness

    to_return.generator.addArg(std.fmt.allocPrint(b.allocator, "-N{s}", .{package_name}) catch @panic("OOM"));
    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_parser);
    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_pycommon);
    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_generator_type_description);

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
        build_deps.rosidl_generator_type_description.path(
            b,
            "bin/rosidl_generator_type_description",
        ),
    );

    return to_return;
}

pub fn addIncludePath(
    self: *RosidlTypeDescription,
    name: []const u8,
    path: std.Build.LazyPath,
) void {
    self.generator.addPrefixedDirectoryArg(
        std.fmt.allocPrint(
            self.generator.step.owner.allocator,
            "-I{s}:",
            .{name},
        ) catch @panic("OOM"),
        path,
    );
}

pub fn addIdlTuple(
    self: *RosidlTypeDescription,
    name: []const u8,
    path: std.Build.LazyPath,
) void {
    self.generator.addPrefixedDirectoryArg(
        std.fmt.allocPrint(self.generator.step.owner.allocator, "-D{s}:", .{name}) catch @panic("OOM"),
        path,
    );
}
