const std = @import("std");

const zigros = @import("../zigros/zigros.zig");
const Interface = @import("../rosidl/src/RosidlGenerator.zig").Interface;

const Dependency = std.Build.Dependency;
const LazyPath = std.Build.LazyPath;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;

pub const Deps = struct {
    upstream: *Dependency,
    tracetools: LazyPath,
    rcutils: *Compile,
    cyclonedds: *Compile,
    rcpputils: *Compile,
    rmw: *Compile,
    rmw_dds_common: *Compile,
    rmw_dds_common_interface: Interface,
    rosidl_runtime_c: *Compile,
    rosidl_typesupport_introspection_c: *Compile,
    rosidl_typesupport_introspection_cpp: *Compile,
    rosidl_dynamic_typesupport: *Compile,
    rosidl_typesupport_interface: LazyPath,
    rosidl_runtime_cpp: LazyPath,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps) *Compile {
    const target = args.target;
    const optimize = args.optimize;

    const linkage = args.linkage;
    const upstream = deps.upstream;
    var lib = std.Build.Step.Compile.create(b, .{
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        },
        .name = "rmw_cyclonedds_cpp",
        .kind = .lib,
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        lib.link_function_sections = true;
        lib.link_data_sections = true;
    }

    lib.linkLibCpp();

    zigros.linkDependencyStruct(&lib.root_module, deps, .cpp);

    lib.addIncludePath(upstream.path("rmw_cyclonedds/rmw_cyclonedds_cpp/src"));
    lib.addCSourceFiles(.{
        .root = upstream.path("rmw_cyclonedds_cpp/"),
        .files = &.{
            "src/rmw_get_network_flow_endpoints.cpp",
            "src/rmw_node.cpp",
            "src/serdata.cpp",
            "src/serdes.cpp",
            "src/u16string.cpp",
            "src/exception.cpp",
            "src/demangle.cpp",
            "src/deserialization_exception.cpp",
            "src/Serialization.cpp",
            "src/TypeSupport2.cpp",
            "src/TypeSupport.cpp",
        },
        .flags = &.{
            "-Wno-deprecated-declarations",
            "--std=c++17",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
            // Note, this is needed because the desserialization does a pointer cast on a byte array to extract larger integers, which is technically missaligned pointer access and should be implemented differently
            "-fno-sanitize=alignment",
        },
    });

    b.installArtifact(lib);
    return lib;
}
