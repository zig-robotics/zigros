const std = @import("std");

const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;

pub const Deps = struct {
    upstream: *Dependency,
    spdlog: *Dependency,
    rcutils: *Compile,
    rcpputils: *Compile,
};

pub const Artifacts = struct {
    rcl_logging_interface: *Compile,
    rcl_logging_spdlog: *Compile,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps) Artifacts {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.upstream;
    const spdlog = deps.spdlog;

    var rcl_logging_interface = b.addLibrary(.{
        .name = "rcl_logging_interface",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rcl_logging_interface.link_function_sections = true;
        rcl_logging_interface.link_data_sections = true;
    }

    rcl_logging_interface.linkLibC();
    rcl_logging_interface.addIncludePath(upstream.path("rcl_logging_interface/include"));

    rcl_logging_interface.linkLibrary(deps.rcutils);

    rcl_logging_interface.addCSourceFiles(.{
        .root = upstream.path("rcl_logging_interface"),
        .files = &.{
            "src/logging_dir.c",
        },
        .flags = &.{
            "-fvisibility=hidden",
        },
    });

    rcl_logging_interface.installHeadersDirectory(
        upstream.path("rcl_logging_interface/include"),
        "",
        .{},
    );
    b.installArtifact(rcl_logging_interface);

    var rcl_logging_spdlog = b.addLibrary(.{
        .name = "rcl_logging_spdlog",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rcl_logging_spdlog.link_function_sections = true;
        rcl_logging_spdlog.link_data_sections = true;
    }

    rcl_logging_spdlog.linkLibCpp();
    rcl_logging_spdlog.addIncludePath(spdlog.path("include"));

    rcl_logging_spdlog.linkLibrary(rcl_logging_interface);
    rcl_logging_spdlog.linkLibrary(deps.rcutils);
    rcl_logging_spdlog.linkLibrary(deps.rcpputils);

    rcl_logging_spdlog.addCSourceFiles(.{
        .root = upstream.path("rcl_logging_spdlog"),
        .files = &.{
            "src/rcl_logging_spdlog.cpp",
        },
        .flags = &.{
            "--std=c++17",
        },
    });

    b.installArtifact(rcl_logging_spdlog);

    return .{
        .rcl_logging_interface = rcl_logging_interface,
        .rcl_logging_spdlog = rcl_logging_spdlog,
    };
}
