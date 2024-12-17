const std = @import("std");

const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;

pub const Deps = struct {
    upstream: *Dependency,
    rcutils: *Compile,
    rosidl_runtime_c: *Compile,
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
        .name = "rmw",
        .kind = .lib,
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        lib.link_function_sections = true;
        lib.link_data_sections = true;
    }

    lib.linkLibC();
    lib.addIncludePath(upstream.path("rmw/include"));

    zigros.linkDependencyStruct(&lib.root_module, deps, .c);

    lib.addCSourceFiles(.{
        .root = upstream.path("rmw"),
        .files = &.{
            "src/allocators.c",
            "src/convert_rcutils_ret_to_rmw_ret.c",
            "src/discovery_options.c",
            "src/event.c",
            "src/init.c",
            "src/init_options.c",
            "src/message_sequence.c",
            "src/names_and_types.c",
            "src/network_flow_endpoint_array.c",
            "src/network_flow_endpoint.c",
            "src/publisher_options.c",
            "src/qos_string_conversions.c",
            "src/sanity_checks.c",
            "src/security_options.c",
            "src/subscription_content_filter_options.c",
            "src/subscription_options.c",
            "src/time.c",
            "src/topic_endpoint_info_array.c",
            "src/topic_endpoint_info.c",
            "src/types.c",
            "src/validate_full_topic_name.c",
            "src/validate_namespace.c",
            "src/validate_node_name.c",
        },
        .flags = &.{"-fvisibility=hidden"},
    });

    lib.installHeadersDirectory(
        upstream.path("rmw/include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );
    b.installArtifact(lib);

    return lib;
}
