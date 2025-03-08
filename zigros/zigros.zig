// Common functions and structs used throughout the zigros build.
const std = @import("std");
const Interface = @import("../rosidl/src/RosidlGenerator.zig").Interface;

pub const Language = enum {
    c,
    cpp,
};

// This links all relevant fields in a struct of dependencies to the provided module.
// This will link any *Compile field, add all lazy paths as include files, and use the link helper
// with any provided Interface types. the lang arg is only used for interfaces for now. If .c is
// provided, linkC is called. If .cpp is provided it calls link.
pub fn linkDependencyStruct(module: *std.Build.Module, dependencies: anytype, lang: Language) void {
    comptime switch (@typeInfo(@TypeOf(dependencies))) {
        .@"struct" => {},
        else => @compileError("dependency type must be a struct"),
    };
    const deps_info = @typeInfo(@TypeOf(dependencies)).@"struct";
    inline for (deps_info.fields) |field| {
        if (field.type == *std.Build.Step.Compile) {
            module.linkLibrary(@field(dependencies, field.name));
        } else if (field.type == std.Build.LazyPath) {
            module.addIncludePath(@field(dependencies, field.name));
        } else if (field.type == Interface) {
            switch (lang) {
                .c => @field(dependencies, field.name).linkC(module),
                .cpp => @field(dependencies, field.name).link(module),
            }
        }
    }
}

pub const PythonDep = union(enum) {
    system: []const u8, // Path to system python executable
    build: *std.Build.Step.Compile,
};

pub const CompileArgs = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode = .static,
};
