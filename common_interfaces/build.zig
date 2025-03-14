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
    builtin_interfaces: RosidlGenerator.Interface,
    service_msgs: RosidlGenerator.Interface,
};

pub const BuildDeps = struct {
    rosidl_generator: RosidlGenerator.BuildDeps,
};

pub const Artifacts = struct {
    actionlib_msgs: RosidlGenerator.Interface,
    diagnostic_msgs: RosidlGenerator.Interface,
    geometry_msgs: RosidlGenerator.Interface,
    nav_msgs: RosidlGenerator.Interface,
    std_msgs: RosidlGenerator.Interface,
    std_srvs: RosidlGenerator.Interface,
    sensor_msgs: RosidlGenerator.Interface,
    shape_msgs: RosidlGenerator.Interface,
    stereo_msgs: RosidlGenerator.Interface,
    trajectory_msgs: RosidlGenerator.Interface,
    visualization_msgs: RosidlGenerator.Interface,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps, build_deps: BuildDeps) Artifacts {
    const upstream = deps.upstream;

    // !! NOTE !!
    // When adding interfaces, the "path" argument must be the root folder of that interface,
    // meaning in this case "std_msgs", NOT the folder where the .msg files reside, e.g.
    // "std_msgs/msg". This is required for proper generation of the interface types namespaced by
    // 'msg', 'srv', etc. This means that each .msg file MUST be listed like "msg/Foo.msg" or
    // "srv/Bar.srv", and NOT like "Foo.msg" or "Bar.srv".

    ///////////////////////////////////////////////////////////////////////////
    // std_msgs
    ///////////////////////////////////////////////////////////////////////////
    var std_msgs = RosidlGenerator.create(
        b,
        "std_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    std_msgs.addInterfaces(upstream.path("std_msgs"), &std_msgs_files);

    // the example message uses the standard header message, so we must add builtin_interfaces
    // as a dependency
    std_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    std_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // std_srvs
    ///////////////////////////////////////////////////////////////////////////
    var std_srvs = RosidlGenerator.create(
        b,
        "std_srvs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    std_srvs.addInterfaces(upstream.path("std_srvs"), &std_srvs_files);
    std_srvs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    std_srvs.addDependency("service_msgs", deps.service_msgs);
    std_srvs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // geometry_msgs
    ///////////////////////////////////////////////////////////////////////////
    var geometry_msgs = RosidlGenerator.create(
        b,
        "geometry_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    geometry_msgs.addInterfaces(upstream.path("geometry_msgs"), &geometry_msgs_files);
    geometry_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    geometry_msgs.addDependency("std_msgs", std_msgs.artifacts);
    geometry_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // actionlib_msgs
    ///////////////////////////////////////////////////////////////////////////
    var actionlib_msgs = RosidlGenerator.create(
        b,
        "actionlib_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    actionlib_msgs.addInterfaces(upstream.path("actionlib_msgs"), &actionlib_msgs_files);
    actionlib_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    actionlib_msgs.addDependency("std_msgs", std_msgs.artifacts);
    actionlib_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // diagnostic_msgs
    ///////////////////////////////////////////////////////////////////////////
    var diagnostic_msgs = RosidlGenerator.create(
        b,
        "diagnostic_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    diagnostic_msgs.addInterfaces(upstream.path("diagnostic_msgs"), &diagnostic_msgs_files);
    diagnostic_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    diagnostic_msgs.addDependency("std_msgs", std_msgs.artifacts);
    diagnostic_msgs.addDependency("geometry_msgs", geometry_msgs.artifacts);
    diagnostic_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // nav_msgs
    ///////////////////////////////////////////////////////////////////////////
    var nav_msgs = RosidlGenerator.create(
        b,
        "nav_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    nav_msgs.addInterfaces(upstream.path("nav_msgs"), &nav_msgs_files);
    nav_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    nav_msgs.addDependency("std_msgs", std_msgs.artifacts);
    nav_msgs.addDependency("geometry_msgs", geometry_msgs.artifacts);
    nav_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // sensor_msgs
    ///////////////////////////////////////////////////////////////////////////
    var sensor_msgs = RosidlGenerator.create(
        b,
        "sensor_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    sensor_msgs.addInterfaces(upstream.path("sensor_msgs"), &sensor_msgs_files);
    sensor_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    sensor_msgs.addDependency("std_msgs", std_msgs.artifacts);
    sensor_msgs.addDependency("geometry_msgs", geometry_msgs.artifacts);
    sensor_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // shape_msgs
    ///////////////////////////////////////////////////////////////////////////
    var shape_msgs = RosidlGenerator.create(
        b,
        "shape_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    shape_msgs.addInterfaces(upstream.path("shape_msgs"), &shape_msgs_files);
    shape_msgs.addDependency("geometry_msgs", geometry_msgs.artifacts);
    shape_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // stereo_msgs
    ///////////////////////////////////////////////////////////////////////////
    var stereo_msgs = RosidlGenerator.create(
        b,
        "stereo_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    stereo_msgs.addInterfaces(upstream.path("stereo_msgs"), &stereo_msgs_files);
    stereo_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    stereo_msgs.addDependency("std_msgs", std_msgs.artifacts);
    stereo_msgs.addDependency("sensor_msgs", sensor_msgs.artifacts);
    stereo_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // trajectory_msgs
    ///////////////////////////////////////////////////////////////////////////
    var trajectory_msgs = RosidlGenerator.create(
        b,
        "trajectory_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    trajectory_msgs.addInterfaces(upstream.path("trajectory_msgs"), &trajectory_msgs_files);
    trajectory_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    trajectory_msgs.addDependency("std_msgs", std_msgs.artifacts);
    trajectory_msgs.addDependency("geometry_msgs", geometry_msgs.artifacts);
    trajectory_msgs.installArtifacts();

    ///////////////////////////////////////////////////////////////////////////
    // visualization_msgs
    ///////////////////////////////////////////////////////////////////////////
    var visualization_msgs = RosidlGenerator.create(
        b,
        "visualization_msgs",
        deps.rosidl_generator,
        build_deps.rosidl_generator,
        args,
    );
    visualization_msgs.addInterfaces(upstream.path("visualization_msgs"), &visualization_msgs_files);
    visualization_msgs.addDependency("builtin_interfaces", deps.builtin_interfaces);
    visualization_msgs.addDependency("std_msgs", std_msgs.artifacts);
    visualization_msgs.addDependency("geometry_msgs", geometry_msgs.artifacts);
    visualization_msgs.addDependency("sensor_msgs", sensor_msgs.artifacts);
    visualization_msgs.installArtifacts();

    return Artifacts{
        .actionlib_msgs = actionlib_msgs.artifacts,
        .diagnostic_msgs = diagnostic_msgs.artifacts,
        .geometry_msgs = geometry_msgs.artifacts,
        .nav_msgs = nav_msgs.artifacts,
        .sensor_msgs = sensor_msgs.artifacts,
        .shape_msgs = shape_msgs.artifacts,
        .std_msgs = std_msgs.artifacts,
        .std_srvs = std_srvs.artifacts,
        .stereo_msgs = stereo_msgs.artifacts,
        .trajectory_msgs = trajectory_msgs.artifacts,
        .visualization_msgs = visualization_msgs.artifacts,
    };
}

const actionlib_msgs_files = [_][]const u8{
    "msg/GoalID.msg",
    "msg/GoalStatusArray.msg",
    "msg/GoalStatus.msg",
};

const diagnostic_msgs_files = [_][]const u8{
    "msg/DiagnosticArray.msg",
    "msg/DiagnosticStatus.msg",
    "msg/KeyValue.msg",
};

const geometry_msgs_files = [_][]const u8{
    "msg/Accel.msg",
    "msg/AccelStamped.msg",
    "msg/AccelWithCovariance.msg",
    "msg/AccelWithCovarianceStamped.msg",
    "msg/Inertia.msg",
    "msg/InertiaStamped.msg",
    "msg/Point32.msg",
    "msg/Point.msg",
    "msg/PointStamped.msg",
    "msg/PolygonInstance.msg",
    "msg/PolygonInstanceStamped.msg",
    "msg/Polygon.msg",
    "msg/PolygonStamped.msg",
    "msg/Pose2D.msg",
    "msg/PoseArray.msg",
    "msg/Pose.msg",
    "msg/PoseStamped.msg",
    "msg/PoseWithCovariance.msg",
    "msg/PoseWithCovarianceStamped.msg",
    "msg/Quaternion.msg",
    "msg/QuaternionStamped.msg",
    "msg/Transform.msg",
    "msg/TransformStamped.msg",
    "msg/Twist.msg",
    "msg/TwistStamped.msg",
    "msg/TwistWithCovariance.msg",
    "msg/TwistWithCovarianceStamped.msg",
    "msg/Vector3.msg",
    "msg/Vector3Stamped.msg",
    "msg/VelocityStamped.msg",
    "msg/Wrench.msg",
    "msg/WrenchStamped.msg",
};

const nav_msgs_files = [_][]const u8{
    "msg/GridCells.msg",
    "msg/MapMetaData.msg",
    "msg/OccupancyGrid.msg",
    "msg/Odometry.msg",
    "msg/Path.msg",
};

const sensor_msgs_files = [_][]const u8{
    "msg/BatteryState.msg",
    "msg/CameraInfo.msg",
    "msg/ChannelFloat32.msg",
    "msg/CompressedImage.msg",
    "msg/FluidPressure.msg",
    "msg/Illuminance.msg",
    "msg/Image.msg",
    "msg/Imu.msg",
    "msg/JointState.msg",
    "msg/JoyFeedbackArray.msg",
    "msg/JoyFeedback.msg",
    "msg/Joy.msg",
    "msg/LaserEcho.msg",
    "msg/LaserScan.msg",
    "msg/MagneticField.msg",
    "msg/MultiDOFJointState.msg",
    "msg/MultiEchoLaserScan.msg",
    "msg/NavSatFix.msg",
    "msg/NavSatStatus.msg",
    "msg/PointCloud2.msg",
    "msg/PointCloud.msg",
    "msg/PointField.msg",
    "msg/Range.msg",
    "msg/RegionOfInterest.msg",
    "msg/RelativeHumidity.msg",
    "msg/Temperature.msg",
    "msg/TimeReference.msg",
};

const shape_msgs_files = [_][]const u8{
    "msg/Mesh.msg",
    "msg/MeshTriangle.msg",
    "msg/Plane.msg",
    "msg/SolidPrimitive.msg",
};

const std_msgs_files = [_][]const u8{
    "msg/Bool.msg",
    "msg/Byte.msg",
    "msg/ByteMultiArray.msg",
    "msg/Char.msg",
    "msg/ColorRGBA.msg",
    "msg/Empty.msg",
    "msg/Float32.msg",
    "msg/Float32MultiArray.msg",
    "msg/Float64.msg",
    "msg/Float64MultiArray.msg",
    "msg/Header.msg",
    "msg/Int16.msg",
    "msg/Int16MultiArray.msg",
    "msg/Int32.msg",
    "msg/Int32MultiArray.msg",
    "msg/Int64.msg",
    "msg/Int64MultiArray.msg",
    "msg/Int8.msg",
    "msg/Int8MultiArray.msg",
    "msg/MultiArrayDimension.msg",
    "msg/MultiArrayLayout.msg",
    "msg/String.msg",
    "msg/UInt16.msg",
    "msg/UInt16MultiArray.msg",
    "msg/UInt32.msg",
    "msg/UInt32MultiArray.msg",
    "msg/UInt64.msg",
    "msg/UInt64MultiArray.msg",
    "msg/UInt8.msg",
    "msg/UInt8MultiArray.msg",
};

const std_srvs_files = [_][]const u8{
    "srv/Empty.srv",
    "srv/SetBool.srv",
    "srv/Trigger.srv",
};

const stereo_msgs_files = [_][]const u8{"msg/DisparityImage.msg"};

const trajectory_msgs_files = [_][]const u8{
    "msg/JointTrajectory.msg",
    "msg/JointTrajectoryPoint.msg",
    "msg/MultiDOFJointTrajectory.msg",
    "msg/MultiDOFJointTrajectoryPoint.msg",
};

const visualization_msgs_files = [_][]const u8{
    "msg/ImageMarker.msg",
    "msg/InteractiveMarkerControl.msg",
    "msg/InteractiveMarkerFeedback.msg",
    "msg/InteractiveMarkerInit.msg",
    "msg/InteractiveMarker.msg",
    "msg/InteractiveMarkerPose.msg",
    "msg/InteractiveMarkerUpdate.msg",
    "msg/MarkerArray.msg",
    "msg/Marker.msg",
    "msg/MenuEntry.msg",
    "msg/MeshFile.msg",
    "msg/UVCoordinate.msg",
};
