const std = @import("std");
const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;
const CompileArgs = zigros.CompileArgs;
const PythonDep = zigros.PythonDep;

pub const Deps = struct {
    upstream: *Dependency,
    rcutils: *Compile,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps) *Compile {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.upstream;
    var lib = b.addLibrary(.{
        .name = "rcpputils",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        lib.link_function_sections = true;
        lib.link_data_sections = true;
    }

    lib.linkLibCpp();
    lib.addIncludePath(upstream.path("include"));

    lib.linkLibrary(deps.rcutils);

    lib.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/asserts.cpp",
            "src/filesystem_helper.cpp",
            "src/find_library.cpp",
            "src/env.cpp",
            "src/shared_library.cpp",
        },
        .flags = &.{
            "--std=c++17",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });

    lib.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{ .include_extensions = &.{".hpp"} },
    );
    b.installArtifact(lib);

    return lib;
}
