const std = @import("std");
const zigros = @import("../zigros/zigros.zig");
const Interface = @import("../rosidl/src/RosidlGenerator.zig").Interface;

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;
const LazyPath = std.Build.LazyPath;
const PythonDep = zigros.PythonDep;

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
    libstatistics_collector: *Compile,
    ament_index_cpp: *Compile,
    rcpputils: *Compile,
    rosidl_runtime_cpp: LazyPath,
    rosidl_typesupport_introspection_cpp: *Compile,
    type_description_interfaces: Interface,
    service_msgs: Interface,
    builtin_interfaces: Interface,
    rcl_interfaces: Interface,
    statistics_msgs: Interface,
    rosgrapg_msgs: Interface,
};

pub const BuildDeps = struct {
    python: PythonDep,
    empy: ?LazyPath,
    rcutils: LazyPath,
};

fn pythonStep(b: *std.Build, command: []const u8, build_deps: BuildDeps) *Run {
    var step = switch (build_deps.python) {
        .system => |python| b.addSystemCommand(&.{ python, "-c", command }),
        .build => |python| blk: {
            var step = b.addRunArtifact(python);
            step.addArgs(&.{ "-I", "-c", command });
            step.addPrefixedDirectoryArg("-P", build_deps.empy.?);
            break :blk step;
        },
    };

    // the rcutils package is always built from ROS, and needs to be passed in both cases
    step.addPrefixedDirectoryArg("-P", build_deps.rcutils);
    return step;
}

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps, build_deps: BuildDeps) *Compile {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.upstream;

    const logger_command =
        \\import sys
        \\for arg in sys.argv:
        \\    if arg.startswith("-P"):
        \\        sys.path.append(arg.lstrip("-P"))
        \\import em
        \\output = sys.argv[-1]
        \\em.invoke(['-o', output, 'resource/logging.hpp.em'])
    ;

    var logger_step = pythonStep(b, logger_command, build_deps);
    logger_step.setCwd(upstream.path("rclcpp")); // for easy access to resource dir
    const logging_output = logger_step.addOutputFileArg("include/rclcpp/logging.hpp");

    var rclcpp = b.addLibrary(.{
        .name = "rclcpp",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rclcpp.link_function_sections = true;
        rclcpp.link_data_sections = true;
    }

    // Add the parent directory to be sure that the file structuree is captured
    rclcpp.addIncludePath(logging_output.dirname().dirname());
    rclcpp.installHeader(logging_output, "rclcpp/logging.hpp");

    const interfaces = &.{
        "node_base_interface",
        "node_clock_interface",
        "node_graph_interface",
        "node_logging_interface",
        "node_parameters_interface",
        "node_services_interface",
        "node_time_source_interface",
        "node_timers_interface",
        "node_topics_interface",
        "node_type_descriptions_interface",
        "node_waitables_interface",
    };
    inline for (interfaces) |interface_name| {
        const interface_command_template =
            \\import sys
            \\for arg in sys.argv:
            \\    if arg.startswith("-P"):
            \\        sys.path.append(arg.lstrip("-P"))
            \\import em
            \\output = sys.argv[-1]
            \\em.invoke(['-D', 'interface_name = \'{[interface_name]s}\'', 
            \\        '-o', output, 'resource/interface_traits.hpp.em'])
        ;
        const interface_output_template =
            "include/rclcpp/node_interfaces/{[interface_name]s}_traits.hpp";
        var buf: [512]u8 = undefined;
        const interface_command = std.fmt.bufPrint(
            &buf,
            interface_command_template,
            .{ .interface_name = interface_name },
        ) catch @panic("out of buffer space");

        var interface_step = pythonStep(b, interface_command, build_deps);
        interface_step.setCwd(upstream.path("rclcpp")); // for easy access to resource

        // safe to use buf here again since addArgs duplicates the string
        const interface_output_arg = std.fmt.bufPrint(
            &buf,
            interface_output_template,
            .{ .interface_name = interface_name },
        ) catch @panic("out of buffer space");
        const interface_output = interface_step.addOutputFileArg(interface_output_arg);

        // Add the parent directory to be sure that the file structuree is captured
        rclcpp.addIncludePath(interface_output.dirname().dirname().dirname());
        rclcpp.installHeader(interface_output, std.mem.trimLeft(u8, interface_output_arg, "include/"));

        const get_command_template =
            \\import sys
            \\for arg in sys.argv:
            \\    if arg.startswith("-P"):
            \\        sys.path.append(arg.lstrip("-P"))
            \\import em
            \\output = sys.argv[-1]
            \\em.invoke(['-D', 'interface_name = \'{[interface_name]s}\'', 
            \\        '-o', output, 'resource/get_interface.hpp.em'])
        ;
        const get_output_template = "include/rclcpp/node_interfaces/get_{[interface_name]s}.hpp";
        const get_command = std.fmt.bufPrint(
            &buf,
            get_command_template,
            .{ .interface_name = interface_name },
        ) catch @panic("out of buffer space");

        var get_step = pythonStep(b, get_command, build_deps);
        get_step.setCwd(upstream.path("rclcpp")); // for easy access to resource

        // safe to use buf here again since addArgs duplicates the string
        const get_output_arg = std.fmt.bufPrint(
            &buf,
            get_output_template,
            .{ .interface_name = interface_name },
        ) catch @panic("out of buffer space");
        const get_output = get_step.addOutputFileArg(get_output_arg);

        // Add the parent directory to be sure that the file structuree is captured
        rclcpp.addIncludePath(get_output.dirname().dirname().dirname());
        rclcpp.installHeader(get_output, std.mem.trimLeft(u8, get_output_arg, "include/"));
    }

    zigros.linkDependencyStruct(rclcpp.root_module, deps, .cpp);

    rclcpp.addIncludePath(upstream.path("rclcpp/include"));
    rclcpp.installHeadersDirectory(
        upstream.path("rclcpp/include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    rclcpp.addCSourceFiles(.{
        .root = upstream.path("rclcpp/src/rclcpp"),
        .files = &.{
            "any_executable.cpp",
            "callback_group.cpp",
            "client.cpp",
            "clock.cpp",
            "context.cpp",
            "contexts/default_context.cpp",
            "create_generic_client.cpp",
            "detail/add_guard_condition_to_rcl_wait_set.cpp",
            "detail/resolve_intra_process_buffer_type.cpp",
            "detail/resolve_parameter_overrides.cpp",
            "detail/rmw_implementation_specific_payload.cpp",
            "detail/rmw_implementation_specific_publisher_payload.cpp",
            "detail/rmw_implementation_specific_subscription_payload.cpp",
            "detail/utilities.cpp",
            "duration.cpp",
            "dynamic_typesupport/dynamic_message.cpp",
            "dynamic_typesupport/dynamic_message_type.cpp",
            "dynamic_typesupport/dynamic_message_type_builder.cpp",
            "dynamic_typesupport/dynamic_message_type_support.cpp",
            "dynamic_typesupport/dynamic_serialization_support.cpp",
            "event.cpp",
            "exceptions/exceptions.cpp",
            "executable_list.cpp",
            "executor.cpp",
            "executor_options.cpp",
            "executors.cpp",
            "executors/executor_entities_collection.cpp",
            "executors/executor_entities_collector.cpp",
            "executors/executor_notify_waitable.cpp",
            "executors/multi_threaded_executor.cpp",
            "executors/single_threaded_executor.cpp",
            "executors/static_single_threaded_executor.cpp",
            "expand_topic_or_service_name.cpp",
            "experimental/executors/events_executor/events_executor.cpp",
            "experimental/timers_manager.cpp",
            "future_return_code.cpp",
            "generic_client.cpp",
            "generic_publisher.cpp",
            "generic_subscription.cpp",
            "graph_listener.cpp",
            "guard_condition.cpp",
            "init_options.cpp",
            "intra_process_manager.cpp",
            "logger.cpp",
            "logging_mutex.cpp",
            "memory_strategies.cpp",
            "memory_strategy.cpp",
            "message_info.cpp",
            "network_flow_endpoint.cpp",
            "node.cpp",
            "node_interfaces/node_base.cpp",
            "node_interfaces/node_clock.cpp",
            "node_interfaces/node_graph.cpp",
            "node_interfaces/node_logging.cpp",
            "node_interfaces/node_parameters.cpp",
            "node_interfaces/node_services.cpp",
            "node_interfaces/node_time_source.cpp",
            "node_interfaces/node_timers.cpp",
            "node_interfaces/node_topics.cpp",
            "node_interfaces/node_type_descriptions.cpp",
            "node_interfaces/node_waitables.cpp",
            "node_options.cpp",
            "parameter.cpp",
            "parameter_client.cpp",
            "parameter_event_handler.cpp",
            "parameter_events_filter.cpp",
            "parameter_map.cpp",
            "parameter_service.cpp",
            "parameter_value.cpp",
            "publisher_base.cpp",
            "qos.cpp",
            "event_handler.cpp",
            "qos_overriding_options.cpp",
            "rate.cpp",
            "serialization.cpp",
            "serialized_message.cpp",
            "service.cpp",
            "signal_handler.cpp",
            "subscription_base.cpp",
            "subscription_intra_process_base.cpp",
            "time.cpp",
            "time_source.cpp",
            "timer.cpp",
            "type_support.cpp",
            "typesupport_helpers.cpp",
            "utilities.cpp",
            "wait_set_policies/detail/write_preferring_read_write_lock.cpp",
            "waitable.cpp",
        },
        .flags = &.{
            "-DROS_PACKAGE_NAME=\"rclcpp\"",
            "-DRCLCPP_BUILDING_LIBRARY",
            "--std=c++17",
            "-Wno-deprecated-declarations",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });
    b.installArtifact(rclcpp);

    return rclcpp;
}
