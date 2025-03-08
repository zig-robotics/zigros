const std = @import("std");
const zigros = @import("../zigros/zigros.zig");
const Interface = @import("../rosidl/src/RosidlGenerator.zig").Interface;

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;
const LazyPath = std.Build.LazyPath;

pub const Deps = struct {
    upstream: *Dependency,
    rcutils: *Compile,
    yaml: *Compile,
    rmw: *Compile,
    tracetools: LazyPath,
    rosidl_runtime_c: *Compile,
    rosidl_dynamic_typesupport: *Compile,
    rosidl_typesupport_interface: LazyPath,
    rcl_logging_interface: *Compile,
    type_description_interfaces: Interface,
    service_msgs: Interface,
    builtin_interfaces: Interface,
    rcl_interfaces: Interface,
};

pub const Artifacts = struct {
    rcl_yaml_param_parser: *Compile,
    rcl: *Compile,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps) Artifacts {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.upstream;

    var yaml_param_parser = b.addLibrary(.{
        .name = "rcl_yaml_param_parser",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    yaml_param_parser.linkLibC();

    yaml_param_parser.addIncludePath(upstream.path("rcl_yaml_param_parser/include"));
    yaml_param_parser.installHeadersDirectory(
        upstream.path("rcl_yaml_param_parser/include"),
        "",
        .{},
    );

    yaml_param_parser.addCSourceFiles(.{
        .root = upstream.path("rcl_yaml_param_parser"),
        .files = &.{
            "src/add_to_arrays.c",
            "src/namespace.c",
            "src/node_params.c",
            "src/parse.c",
            "src/parser.c",
            "src/yaml_variant.c",
        },
        .flags = &.{
            "-fvisibility=hidden",
        },
    });
    yaml_param_parser.linkLibrary(deps.rmw);

    yaml_param_parser.linkLibrary(deps.yaml);
    yaml_param_parser.linkLibrary(deps.rcutils);
    b.installArtifact(yaml_param_parser);

    var rcl = b.addLibrary(.{
        .name = "rcl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    rcl.addIncludePath(deps.tracetools);

    rcl.addIncludePath(upstream.path("rcl/include"));
    rcl.addIncludePath(upstream.path("rcl/src"));
    rcl.installHeadersDirectory(upstream.path("rcl/include"), "", .{});

    zigros.linkDependencyStruct(rcl.root_module, deps, .c);
    rcl.linkLibrary(yaml_param_parser);

    rcl.addCSourceFiles(.{
        .root = upstream.path("rcl/src/rcl"),
        .files = &.{
            "arguments.c",
            "client.c",
            "common.c",
            "context.c",
            "discovery_options.c",
            "domain_id.c",
            "dynamic_message_type_support.c",
            "event.c",
            "expand_topic_name.c",
            "graph.c",
            "guard_condition.c",
            "init.c",
            "init_options.c",
            "lexer.c",
            "lexer_lookahead.c",
            "localhost.c",
            "logging.c",
            "logging_rosout.c",
            "log_level.c",
            "network_flow_endpoints.c",
            "node.c",
            "node_options.c",
            "node_resolve_name.c",
            "node_type_cache.c",
            "publisher.c",
            "remap.c",
            "rmw_implementation_identifier_check.c",
            "security.c",
            "service.c",
            "service_event_publisher.c",
            "subscription.c",
            "time.c",
            "timer.c",
            "type_description_conversions.c",
            "type_hash.c",
            "validate_enclave_name.c",
            "validate_topic_name.c",
            "wait.c",
        },
        .flags = &.{
            "-DROS_PACKAGE_NAME=\"rcl\"",
            "-fvisibility=hidden",
        },
    });
    b.installArtifact(rcl);

    return Artifacts{
        .rcl_yaml_param_parser = yaml_param_parser,
        .rcl = rcl,
    };
}
