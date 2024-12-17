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
    rosidl_generator: RosidlGenerator.Deps,
};

pub const BuildDeps = struct {
    rosidl_generator: RosidlGenerator.BuildDeps,
};

pub const Artifacts = struct {
    builtin_interfaces: RosidlGenerator.Interface,
    rosgraph_msgs: RosidlGenerator.Interface,
    service_msgs: RosidlGenerator.Interface,
    type_description_interfaces: RosidlGenerator.Interface,
    statistics_msgs: RosidlGenerator.Interface,
    rcl_interfaces: RosidlGenerator.Interface,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps, build_deps: BuildDeps) Artifacts {
    const upstream = deps.upstream;

    var builtin_interfaces = RosidlGenerator.create(
        b,
        "builtin_interfaces",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    builtin_interfaces.addInterfaces(upstream.path("builtin_interfaces"), &.{
        "msg/Time.msg",
        "msg/Duration.msg",
    });

    builtin_interfaces.installArtifacts();

    var rosgraph_msgs = RosidlGenerator.create(
        b,
        "rosgraph_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    rosgraph_msgs.addInterfaces(upstream.path("rosgraph_msgs"), &.{
        "msg/Clock.msg",
    });

    rosgraph_msgs.addDependency("builtin_interfaces", builtin_interfaces.artifacts);
    rosgraph_msgs.installArtifacts();

    var service_msgs = RosidlGenerator.create(
        b,
        "service_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    service_msgs.addInterfaces(
        upstream.path("service_msgs"),
        &.{"msg/ServiceEventInfo.msg"},
    );

    service_msgs.addDependency("builtin_interfaces", builtin_interfaces.artifacts);

    service_msgs.installArtifacts();

    var type_description_interfaces = RosidlGenerator.create(
        b,
        "type_description_interfaces",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    type_description_interfaces.addInterfaces(
        upstream.path("type_description_interfaces"),
        &.{
            "msg/Field.msg",
            "msg/FieldType.msg",
            "msg/IndividualTypeDescription.msg",
            "msg/KeyValue.msg",
            "msg/TypeDescription.msg",
            "msg/TypeSource.msg",
            "srv/GetTypeDescription.srv",
        },
    );

    type_description_interfaces.addDependency(
        "builtin_interfaces",
        builtin_interfaces.artifacts,
    );
    type_description_interfaces.addDependency("service_msgs", service_msgs.artifacts);

    type_description_interfaces.installArtifacts();

    var statistics_msgs = RosidlGenerator.create(
        b,
        "statistics_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    statistics_msgs.addInterfaces(
        upstream.path("statistics_msgs"),
        &.{
            "msg/MetricsMessage.msg",
            "msg/StatisticDataPoint.msg",
            "msg/StatisticDataType.msg",
        },
    );

    statistics_msgs.addDependency("builtin_interfaces", builtin_interfaces.artifacts);

    statistics_msgs.installArtifacts();

    var rcl_interfaces = RosidlGenerator.create(
        b,
        "rcl_interfaces",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );

    rcl_interfaces.addInterfaces(
        upstream.path("rcl_interfaces"),
        &.{
            "msg/FloatingPointRange.msg",
            "msg/IntegerRange.msg",
            "msg/ListParametersResult.msg",
            "msg/Log.msg",
            "msg/ParameterDescriptor.msg",
            "msg/ParameterEventDescriptors.msg",
            "msg/ParameterEvent.msg",
            "msg/Parameter.msg",
            "msg/ParameterType.msg",
            "msg/ParameterValue.msg",
            "msg/SetParametersResult.msg",
            "msg/LoggerLevel.msg",
            "msg/SetLoggerLevelsResult.msg",
            "srv/DescribeParameters.srv",
            "srv/GetParameters.srv",
            "srv/GetParameterTypes.srv",
            "srv/ListParameters.srv",
            "srv/SetParametersAtomically.srv",
            "srv/SetParameters.srv",
            "srv/GetLoggerLevels.srv",
            "srv/SetLoggerLevels.srv",
        },
    );

    rcl_interfaces.addDependency("builtin_interfaces", builtin_interfaces.artifacts);
    rcl_interfaces.addDependency("service_msgs", service_msgs.artifacts);

    rcl_interfaces.installArtifacts();

    return Artifacts{
        .builtin_interfaces = builtin_interfaces.artifacts,
        .rosgraph_msgs = rosgraph_msgs.artifacts,
        .service_msgs = service_msgs.artifacts,
        .type_description_interfaces = type_description_interfaces.artifacts,
        .statistics_msgs = statistics_msgs.artifacts,
        .rcl_interfaces = rcl_interfaces.artifacts,
    };
}
