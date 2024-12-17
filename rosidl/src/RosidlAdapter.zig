const Interface2Idl = @This();

const std = @import("std");
const RosidlGenerator = @import("RosidlGenerator.zig");

generator: *std.Build.Step.Run,
output: std.Build.LazyPath,

pub fn create(b: *std.Build, build_deps: RosidlGenerator.BuildDeps, package_name: []const u8) *Interface2Idl {
    const to_return = b.allocator.create(Interface2Idl) catch @panic("OOM");
    to_return.generator = b.addRunArtifact(build_deps.adapter_generator);

    to_return.output = to_return.generator.addPrefixedOutputDirectoryArg(
        "-O",
        std.fmt.allocPrint(
            b.allocator,
            "{s}__rosidl_adapter_output",
            .{package_name},
        ) catch @panic("OOM"),
    );
    to_return.generator.addArg(std.fmt.allocPrint(
        b.allocator,
        "-N{s}",
        .{package_name},
    ) catch @panic("OOM"));

    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_cli);
    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_adapter);
    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_parser);
    to_return.generator.addPrefixedDirectoryArg("-P", build_deps.rosidl_pycommon);

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
            to_return.generator.addPrefixedFileArg("-B", python.getEmittedBin());
        },
    }

    return to_return;
}

pub fn addInterface(self: *Interface2Idl, path: std.Build.LazyPath, interface: []const u8) void {
    // Add the file explicitly for caching purposes, the Z prefixed arguments are ignored.
    // Without this, the cache is not invalidated on interface file modifications
    self.generator.addPrefixedFileArg("-Z", path.path(self.generator.step.owner, interface));
    self.generator.addPrefixedDirectoryArg(
        std.fmt.allocPrint(
            self.generator.step.owner.allocator,
            "-D{s}:",
            .{interface},
        ) catch @panic("OOM"),
        path,
    );
}
