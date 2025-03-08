const std = @import("std");
const RosidlGenerator = @import("../rosidl/src/RosidlGenerator.zig");

const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;
const CompileArgs = zigros.CompileArgs;

pub const Deps = struct {
    upstream: *Dependency,
    rcutils: *Compile,
    rcpputils: *Compile,
    rmw: *Compile,
    rosidl_runtime_c: *Compile,
    rosidl_runtime_cpp: LazyPath,
    rosidl_typesupport_interface: LazyPath,
    rosidl_generator: RosidlGenerator.Deps,
};

pub const BuildDeps = struct {
    rosidl_generator: RosidlGenerator.BuildDeps,
};

pub const Artifacts = struct {
    rmw_dds_common_interface: RosidlGenerator.Interface,
    rmw_dds_common: *Compile,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps, build_deps: BuildDeps) Artifacts {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = b.dependency("rmw_dds_common", .{});

    var rmw_dds_common = b.addLibrary(.{
        .name = "rmw_dds_common",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rmw_dds_common.link_function_sections = true;
        rmw_dds_common.link_data_sections = true;
    }

    rmw_dds_common.linkLibCpp();
    zigros.linkDependencyStruct(rmw_dds_common.root_module, deps, .cpp);

    // Generate interfaces that the rmw_dds_common artifact depensd on
    var interface_generator = RosidlGenerator.create(
        b,
        "rmw_dds_common",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    interface_generator.addInterfaces(upstream.path("rmw_dds_common"), &.{
        "msg/Gid.msg",
        "msg/NodeEntitiesInfo.msg",
        "msg/ParticipantEntitiesInfo.msg",
    });

    rmw_dds_common.linkLibrary(deps.rosidl_runtime_c);

    interface_generator.artifacts.link(rmw_dds_common.root_module);

    rmw_dds_common.addIncludePath(upstream.path("rmw_dds_common/include"));

    rmw_dds_common.addCSourceFiles(.{
        .root = upstream.path("rmw_dds_common"),
        .files = &.{
            "src/context.cpp",
            "src/gid_utils.cpp",
            "src/graph_cache.cpp",
            "src/qos.cpp",
            "src/security.cpp",
            "src/time_utils.cpp",
        },
        .flags = &.{
            "-Wno-deprecated-declarations",
            "--std=c++17",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });

    rmw_dds_common.installHeadersDirectory(
        upstream.path("rmw_dds_common/include"),
        "",
        .{ .include_extensions = &.{ ".hpp", ".h" } },
    );
    b.installArtifact(rmw_dds_common);
    interface_generator.installArtifacts();

    return .{
        .rmw_dds_common_interface = interface_generator.artifacts,
        .rmw_dds_common = rmw_dds_common,
    };
}
