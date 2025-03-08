const std = @import("std");

const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const LazyPath = std.Build.LazyPath;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;
const Interface = @import("../rosidl/src/RosidlGenerator.zig").Interface;

pub const Deps = struct {
    upstream: *Dependency,
    rcl: *Compile,
    rcl_yaml_param_parser: *Compile,
    rcl_logging_interface: *Compile,
    yaml: *Compile,
    rcutils: *Compile,
    rmw: *Compile,
    rosidl_dynamic_typesupport: *Compile,
    rosidl_runtime_c: *Compile,
    rosidl_typesupport_interface: LazyPath,
    tracetools: LazyPath,
    type_description_interfaces: Interface,
    service_msgs: Interface,
    builtin_interfaces: Interface,
    rcl_interfaces: Interface,
    rcpputils: *Compile,
    rosidl_runtime_cpp: LazyPath,
    statistics_msgs: Interface,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps) *Compile {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.upstream;

    var lib = b.addLibrary(.{
        .name = "libstatistics_collector",
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
    lib.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    zigros.linkDependencyStruct(lib.root_module, deps, .cpp);

    lib.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{
            "libstatistics_collector/collector/collector.cpp",
            "libstatistics_collector/collector/generate_statistics_message.cpp",
            "libstatistics_collector/moving_average_statistics/moving_average.cpp",
            "libstatistics_collector/moving_average_statistics/types.cpp",
        },
        .flags = &.{
            "-std=c++17",
            "-Wno-deprecated-declarations",
            "-DLIBSTATISTICS_COLLECTOR_BUILDING_LIBRARY",
            // "-fvisibility=hidden",  // TODO visibility hidden breaks this package
            // "-fvisibility-inlines-hidden",
        },
    });

    b.installArtifact(lib);

    return lib;
}
