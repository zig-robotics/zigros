const std = @import("std");
const zigros = @import("zigros/zigros.zig");

const rcutils = @import("rcutils/build.zig");
const rcpputils = @import("rcpputils/build.zig");
const rosidl = @import("rosidl/build.zig");
const RosidlGenerator = @import("rosidl/src/RosidlGenerator.zig");
const rmw = @import("rmw/build.zig");
const rmw_dds_common = @import("rmw_dds_common/build.zig");
const rcl_logging = @import("rcl_logging/build.zig");
const rcl_interfaces = @import("rcl_interfaces/build.zig");
const common_interfaces = @import("common_interfaces/build.zig");
const ros2_tracing = @import("ros2_tracing/build.zig");
const rcl = @import("rcl/build.zig");
const rmw_cyclonedds = @import("rmw_cyclonedds/build.zig");
const libstatistics_collector = @import("libstatistics_collector/build.zig");
const ament_index = @import("ament_index/build.zig");
const rclcpp = @import("rclcpp/build.zig");

const LazyPath = std.Build.LazyPath;
const Dependency = std.Build.Dependency;
const Compile = std.Build.Step.Compile;
const Module = std.Build.Module;
const WriteFile = std.Build.Step.WriteFile;

const UpstreamDependencies = struct {
    rcutils: *Dependency,
    rcpputils: *Dependency,
    rosidl: *Dependency,
    rosidl_typesupport: *Dependency,
    rosidl_dynamic_typesupport: *Dependency,
    rmw: *Dependency,
    rmw_dds_common: *Dependency,
    rcl_logging: *Dependency,
    spdlog: *Dependency,
    rcl_interfaces: *Dependency,
    common_interfaces: *Dependency,
    ros2_tracing: *Dependency,
    rcl: *Dependency,
    rmw_cyclonedds: *Dependency,
    libstatistics_collector: *Dependency,
    ament_index: *Dependency,
    rclcpp: *Dependency,
};

const RosLibraries = struct {
    rcutils: *Compile,
    rcpputils: *Compile,
    rosidl_typesupport_interface: LazyPath,
    rosidl_runtime_c: *Compile,
    rosidl_runtime_cpp: LazyPath,
    rosidl_typesupport_introspection_c: *Compile,
    rosidl_typesupport_introspection_cpp: *Compile,
    rosidl_typesupport_c: *Compile,
    rosidl_typesupport_cpp: *Compile,
    rosidl_dynamic_typesupport: *Compile,
    rmw: *Compile,
    rmw_dds_common: *Compile,
    rmw_dds_common_interface: RosidlGenerator.Interface,
    rcl_logging_interface: *Compile,
    rcl_logging_spdlog: *Compile,
    builtin_interfaces: RosidlGenerator.Interface,
    rosgraph_msgs: RosidlGenerator.Interface,
    service_msgs: RosidlGenerator.Interface,
    type_description_interfaces: RosidlGenerator.Interface,
    statistics_msgs: RosidlGenerator.Interface,
    rcl_interfaces: RosidlGenerator.Interface,
    tracetools: LazyPath,
    rcl_yaml_param_parser: *Compile,
    yaml: *Compile, // External
    rcl: *Compile,
    rmw_cyclonedds_cpp: *Compile,
    cyclonedds: *Compile, // External
    libstatistics_collector: *Compile,
    ament_index_cpp: *Compile,
    rclcpp: *Compile,
    // common_interfaces:
    actionlib_msgs: RosidlGenerator.Interface,
    diagnostic_msgs: RosidlGenerator.Interface,
    geometry_msgs: RosidlGenerator.Interface,
    nav_msgs: RosidlGenerator.Interface,
    sensor_msgs: RosidlGenerator.Interface,
    shape_msgs: RosidlGenerator.Interface,
    std_msgs: RosidlGenerator.Interface,
    std_srvs: RosidlGenerator.Interface,
    stereo_msgs: RosidlGenerator.Interface,
    trajectory_msgs: RosidlGenerator.Interface,
    visualization_msgs: RosidlGenerator.Interface,
};

const PythonLibraries = struct {
    empy: ?LazyPath,
    lark: ?LazyPath,
    rcutils: LazyPath,
    rosidl_adapter: LazyPath,
    rosidl_cli: LazyPath,
    rosidl_pycommon: LazyPath,
    rosidl_generator_c: LazyPath,
    rosidl_generator_cpp: LazyPath,
    rosidl_generator_type_description: LazyPath,
    rosidl_parser: LazyPath,
    rosidl_typesupport_introspection_c: LazyPath,
    rosidl_typesupport_introspection_cpp: LazyPath,
    rosidl_typesupport_c: LazyPath,
    rosidl_typesupport_cpp: LazyPath,
};

//  Extracts the expected artifacts given a package name
pub fn extractInterface(dep: *std.Build.Dependency, name: []const u8) RosidlGenerator.Interface {
    var buf: [256]u8 = undefined;
    return RosidlGenerator.Interface{
        .share = dep.namedWriteFiles(name).getDirectory(),
        .interface_c = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}__rosidl_generator_c",
            .{name},
        ) catch @panic("Buffer too small")),
        .interface_cpp = dep.namedWriteFiles(std.fmt.bufPrint(
            &buf,
            "{s}__rosidl_generator_cpp",
            .{name},
        ) catch @panic("Buffer too small")).getDirectory(),
        .typesupport_c = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}__rosidl_typesupport_c",
            .{name},
        ) catch @panic("Buffer too small")),
        .typesupport_cpp = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}__rosidl_typesupport_cpp",
            .{name},
        ) catch @panic("Buffer too small")),
        .typesupport_introspection_c = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}__rosidl_typesupport_introspection_c",
            .{name},
        ) catch @panic("Buffer too small")),
        .typesupport_introspection_cpp = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}__rosidl_typesupport_introspection_cpp",
            .{name},
        ) catch @panic("Buffer too small")),
        .c = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}_c",
            .{name},
        ) catch @panic("Buffer too small")),
        .cpp = dep.artifact(std.fmt.bufPrint(
            &buf,
            "{s}_cpp",
            .{name},
        ) catch @panic("Buffer too small")),
    };
}

// The build/configure step sets this if its missing lazy deps which allows the ZigRos init call to return null if it's not set
var lazy_deps_needed = false; // TODO this shouldn't need to be global anymore?
pub fn createInterface(
    dep: *std.Build.Dependency,
    b: *std.Build,
    name: []const u8,
    compile_args: zigros.CompileArgs,
) ?*RosidlGenerator {
    const system_python = if (dep.builder.user_input_options.get(system_python_arg_name)) |option| switch (option.value) {
        .flag => true,
        .scalar => |s| std.mem.eql(u8, s, "true"),
        else => system_python_default,
    } else system_python_default;
    // if (lazy_deps_needed) return null; // TODO is this still required?
    // If built python is used, mark the lazy dependencies as required by early fetching and returning null if any are missing
    var python: ?*std.Build.Dependency = null;
    var empy: ?*std.Build.Dependency = null;
    var lark: ?*std.Build.Dependency = null;
    if (!system_python) {
        python = dep.builder.lazyDependency("python", .{ .optimize = .ReleaseFast, .target = dep.builder.resolveTargetQuery(.{ .abi = .musl }) });
        empy = dep.builder.lazyDependency("empy", .{});
        lark = dep.builder.lazyDependency("lark", .{});
        if (empy == null or lark == null or python == null) return null;
    }
    return RosidlGenerator.create(
        b,
        name,
        .{
            .rcutils = dep.artifact("rcutils"),
            .rosidl_typesupport_interface = dep.namedWriteFiles(
                "rosidl_typesupport_interface",
            ).getDirectory(),
            .rosidl_runtime_c = dep.artifact("rosidl_runtime_c"),
            .rosidl_runtime_cpp = dep.namedWriteFiles("rosidl_runtime_cpp").getDirectory(),
            .rosidl_typesupport_c = dep.artifact("rosidl_typesupport_c"),
            .rosidl_typesupport_cpp = dep.artifact("rosidl_typesupport_cpp"),
            .rosidl_typesupport_introspection_c = dep.artifact(
                "rosidl_typesupport_introspection_c",
            ),
            .rosidl_typesupport_introspection_cpp = dep.artifact(
                "rosidl_typesupport_introspection_cpp",
            ),
        },
        .{
            .python = if (!system_python)
                // note python is forced to musl to fix an issue building within alpine
                .{ .build = python.?.artifact("cpython") }
            else
                .{ .system = system_python_exe },
            .empy = if (!system_python) empy.?.path("") else null,
            .lark = if (!system_python) lark.?.path("") else null,
            .rosidl_adapter = dep.namedWriteFiles("rosidl_adapter").getDirectory(),
            .rosidl_cli = dep.namedWriteFiles("rosidl_cli").getDirectory(),
            .rosidl_pycommon = dep.namedWriteFiles("rosidl_pycommon").getDirectory(),
            .rosidl_generator_c = dep.namedWriteFiles("rosidl_generator_c").getDirectory(),
            .rosidl_generator_cpp = dep.namedWriteFiles("rosidl_generator_cpp").getDirectory(),
            .rosidl_generator_type_description = dep.namedWriteFiles("rosidl_generator_type_description").getDirectory(),
            .rosidl_parser = dep.namedWriteFiles("rosidl_parser").getDirectory(),
            .rosidl_typesupport_introspection_c = dep.namedWriteFiles("rosidl_typesupport_introspection_c").getDirectory(),
            .rosidl_typesupport_introspection_cpp = dep.namedWriteFiles("rosidl_typesupport_introspection_cpp").getDirectory(),
            .rosidl_typesupport_c = dep.namedWriteFiles("rosidl_typesupport_c").getDirectory(),
            .rosidl_typesupport_cpp = dep.namedWriteFiles("rosidl_typesupport_cpp").getDirectory(),
            .type_description_generator = dep.artifact("type_description_generator"),
            .adapter_generator = dep.artifact("adapter_generator"),
            .code_generator = dep.artifact("code_generator"),
        },
        compile_args,
    );
}

const system_python_default = false;
const system_python_arg_name = "system-python";
const system_python_exe = "python3";

pub fn build(b: *std.Build) void {
    // Common compile arguments that all ROS subbuilds accept
    const compile_args = zigros.CompileArgs{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .linkage = b.option(
            std.builtin.LinkMode,
            "linkage",
            "Specify static or dynamic linkage",
        ) orelse .static,
    };

    const system_python = b.option(
        bool,
        system_python_arg_name,
        "If specified, use the system python and python dependencies instead of building python from source. This will save some time on first build, but adds system dependencies outside of zigs control.",
    ) orelse false;

    // Much of ROS requires python for code generation during the build process.
    var python_libraries = PythonLibraries{
        .empy = null,
        .lark = null,
        .rcutils = undefined,
        .rosidl_adapter = undefined,
        .rosidl_cli = undefined,
        .rosidl_pycommon = undefined,
        .rosidl_generator_c = undefined,
        .rosidl_generator_cpp = undefined,
        .rosidl_generator_type_description = undefined,
        .rosidl_parser = undefined,
        .rosidl_typesupport_introspection_c = undefined,
        .rosidl_typesupport_introspection_cpp = undefined,
        .rosidl_typesupport_c = undefined,
        .rosidl_typesupport_cpp = undefined,
    };

    // All upstream dependencies are direct ROS packages that do not contain zig build files
    // As such, we don't need to pass any arguments
    const upstream_dependencies = UpstreamDependencies{
        .rcutils = b.dependency("rcutils", .{}),
        .rcpputils = b.dependency("rcpputils", .{}),
        .rosidl = b.dependency("rosidl", .{}),
        .rosidl_typesupport = b.dependency("rosidl_typesupport", .{}),
        .rosidl_dynamic_typesupport = b.dependency("rosidl_dynamic_typesupport", .{}),
        .rmw = b.dependency("rmw", .{}),
        .rmw_dds_common = b.dependency("rmw_dds_common", .{}),
        .rcl_logging = b.dependency("rcl_logging", .{}),
        .spdlog = b.dependency("spdlog", .{}),
        .rcl_interfaces = b.dependency("rcl_interfaces", .{}),
        .common_interfaces = b.dependency("ros2_common_interfaces", .{}),
        .ros2_tracing = b.dependency("ros2_tracing", .{}),
        .rcl = b.dependency("rcl", .{}),
        .rmw_cyclonedds = b.dependency("rmw_cyclonedds", .{}),
        .libstatistics_collector = b.dependency("libstatistics_collector", .{}),
        .ament_index = b.dependency("ament_index", .{}),
        .rclcpp = if (compile_args.linkage == .static) b.lazyDependency("rclcpp", .{}) orelse blk: {
            lazy_deps_needed = true;
            break :blk undefined;
        } else b.lazyDependency("rclcpp_visibility_control", .{}) orelse blk: {
            lazy_deps_needed = true;
            break :blk undefined;
        },
    };

    const python = if (system_python)
        zigros.PythonDep{ .system = system_python_exe }
    else blk: {
        const empy = b.lazyDependency("empy", .{});
        const lark = b.lazyDependency("lark", .{});
        // note python is forced to musl to fix an issue building within alpine.
        // The target here is native + musl since python is only used during build.
        const py = b.lazyDependency("python", .{ .optimize = .ReleaseFast, .target = b.resolveTargetQuery(.{ .abi = .musl }) });
        if (empy != null and lark != null and py != null) {
            python_libraries.empy = empy.?.path("");
            python_libraries.lark = lark.?.path("");
            break :blk zigros.PythonDep{ .build = py.?.artifact("cpython") };
        } else {
            lazy_deps_needed = true;
            break :blk undefined;
        }
    };

    // All lazy deps need to be sorted by now
    if (lazy_deps_needed) return;

    var ros_libraries: RosLibraries = undefined;
    const rcutils_artifacts = rcutils.buildWithArgs(
        b,
        compile_args,
        .{ .upstream = upstream_dependencies.rcutils },
        .{ .python = python, .empy = python_libraries.empy },
    );

    ros_libraries.rcutils = rcutils_artifacts.rcutils;
    python_libraries.rcutils = rcutils_artifacts.rcutils_py.getDirectory();

    ros_libraries.rcpputils = rcpputils.buildWithArgs(
        b,
        compile_args,
        .{ .upstream = upstream_dependencies.rcpputils, .rcutils = ros_libraries.rcutils },
    );

    const rosidl_artifacts = rosidl.buildWithArgs(b, compile_args, .{
        .rosidl_upstream = b.dependency("rosidl", .{}),
        .rosidl_typesupport_upstream = b.dependency("rosidl_typesupport", .{}),
        .rosidl_dynamic_typesupport_upstream = b.dependency("rosidl_dynamic_typesupport", .{}),
        .rcutils = ros_libraries.rcutils,
        .rcpputils = ros_libraries.rcpputils,
    }, .{ .python = python, .empy = python_libraries.empy });

    ros_libraries.rosidl_typesupport_interface = rosidl_artifacts.rosidl_typesupport_interface;
    ros_libraries.rosidl_runtime_c = rosidl_artifacts.rosidl_runtime_c;
    ros_libraries.rosidl_runtime_cpp = rosidl_artifacts.rosidl_runtime_cpp;
    ros_libraries.rosidl_typesupport_introspection_c =
        rosidl_artifacts.rosidl_typesupport_introspection_c;
    ros_libraries.rosidl_typesupport_introspection_cpp =
        rosidl_artifacts.rosidl_typesupport_introspection_cpp;
    ros_libraries.rosidl_typesupport_c = rosidl_artifacts.rosidl_typesupport_c;
    ros_libraries.rosidl_typesupport_cpp = rosidl_artifacts.rosidl_typesupport_cpp;
    ros_libraries.rosidl_dynamic_typesupport = rosidl_artifacts.rosidl_dynamic_typesupport;
    python_libraries.rosidl_adapter = rosidl_artifacts.rosidl_adapter_py;
    python_libraries.rosidl_cli = rosidl_artifacts.rosidl_cli_py;
    python_libraries.rosidl_pycommon = rosidl_artifacts.rosidl_pycommon_py;
    python_libraries.rosidl_generator_c = rosidl_artifacts.rosidl_generator_c_py;
    python_libraries.rosidl_generator_cpp = rosidl_artifacts.rosidl_generator_cpp_py;
    python_libraries.rosidl_generator_type_description =
        rosidl_artifacts.rosidl_generator_type_description_py;
    python_libraries.rosidl_parser = rosidl_artifacts.rosidl_parser_py;
    python_libraries.rosidl_typesupport_introspection_c =
        rosidl_artifacts.rosidl_typesupport_introspection_c_py;
    python_libraries.rosidl_typesupport_introspection_cpp =
        rosidl_artifacts.rosidl_typesupport_introspection_cpp_py;
    python_libraries.rosidl_typesupport_c = rosidl_artifacts.rosidl_typesupport_c_py;
    python_libraries.rosidl_typesupport_cpp = rosidl_artifacts.rosidl_typesupport_cpp_py;

    ros_libraries.rmw = rmw.buildWithArgs(b, compile_args, .{
        .upstream = upstream_dependencies.rmw,
        .rcutils = ros_libraries.rcutils,
        .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
    });

    const rosidl_generator_deps = RosidlGenerator.Deps{
        .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
        .rosidl_runtime_cpp = ros_libraries.rosidl_runtime_cpp,
        .rosidl_typesupport_interface = ros_libraries.rosidl_typesupport_interface,
        .rosidl_typesupport_c = ros_libraries.rosidl_typesupport_c,
        .rosidl_typesupport_cpp = ros_libraries.rosidl_typesupport_cpp,
        .rosidl_typesupport_introspection_c = ros_libraries.rosidl_typesupport_introspection_c,
        .rosidl_typesupport_introspection_cpp = ros_libraries.rosidl_typesupport_introspection_cpp,
        .rcutils = ros_libraries.rcutils,
    };
    const rosidl_generator_build_deps = RosidlGenerator.BuildDeps{
        .python = python,
        .empy = python_libraries.empy,
        .lark = python_libraries.lark,
        .rosidl_cli = python_libraries.rosidl_cli,
        .rosidl_adapter = python_libraries.rosidl_adapter,
        .rosidl_parser = python_libraries.rosidl_parser,
        .rosidl_pycommon = python_libraries.rosidl_pycommon,
        .rosidl_generator_type_description = python_libraries.rosidl_generator_type_description,
        .rosidl_generator_c = python_libraries.rosidl_generator_c,
        .rosidl_generator_cpp = python_libraries.rosidl_generator_cpp,
        .rosidl_typesupport_c = python_libraries.rosidl_typesupport_c,
        .rosidl_typesupport_cpp = python_libraries.rosidl_typesupport_cpp,
        .rosidl_typesupport_introspection_c = python_libraries.rosidl_typesupport_introspection_c,
        .rosidl_typesupport_introspection_cpp = python_libraries.rosidl_typesupport_introspection_cpp,
        .type_description_generator = rosidl_artifacts.type_description_generator,
        .adapter_generator = rosidl_artifacts.adapter_generator,
        .code_generator = rosidl_artifacts.code_generator,
    };

    const rmw_dds_common_artifacts = rmw_dds_common.buildWithArgs(
        b,
        compile_args,
        .{
            .upstream = upstream_dependencies.rmw_dds_common,
            .rcutils = ros_libraries.rcutils,
            .rcpputils = ros_libraries.rcpputils,
            .rmw = ros_libraries.rmw,
            .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
            .rosidl_runtime_cpp = ros_libraries.rosidl_runtime_cpp,
            .rosidl_typesupport_interface = ros_libraries.rosidl_typesupport_interface,
            .rosidl_generator = rosidl_generator_deps,
        },
        .{ .rosidl_generator = rosidl_generator_build_deps },
    );

    ros_libraries.rmw_dds_common = rmw_dds_common_artifacts.rmw_dds_common;
    ros_libraries.rmw_dds_common_interface = rmw_dds_common_artifacts.rmw_dds_common_interface;

    const rcl_logging_artifacts = rcl_logging.buildWithArgs(
        b,
        compile_args,
        .{
            .upstream = upstream_dependencies.rcl_logging,
            .spdlog = upstream_dependencies.spdlog,
            .rcutils = ros_libraries.rcutils,
            .rcpputils = ros_libraries.rcpputils,
        },
    );

    ros_libraries.rcl_logging_interface = rcl_logging_artifacts.rcl_logging_interface;
    ros_libraries.rcl_logging_spdlog = rcl_logging_artifacts.rcl_logging_spdlog;

    const rcl_interfaces_artifacts = rcl_interfaces.buildWithArgs(
        b,
        compile_args,
        .{
            .upstream = upstream_dependencies.rcl_interfaces,
            .rosidl_generator = rosidl_generator_deps,
        },
        .{ .rosidl_generator = rosidl_generator_build_deps },
    );

    ros_libraries.builtin_interfaces = rcl_interfaces_artifacts.builtin_interfaces;
    ros_libraries.rosgraph_msgs = rcl_interfaces_artifacts.rosgraph_msgs;
    ros_libraries.service_msgs = rcl_interfaces_artifacts.service_msgs;
    ros_libraries.type_description_interfaces =
        rcl_interfaces_artifacts.type_description_interfaces;
    ros_libraries.statistics_msgs = rcl_interfaces_artifacts.statistics_msgs;
    ros_libraries.rcl_interfaces = rcl_interfaces_artifacts.rcl_interfaces;

    ros_libraries.tracetools = ros2_tracing.build(b);

    const common_interfaces_artifacts = common_interfaces.buildWithArgs(
        b,
        compile_args,
        .{
            .upstream = upstream_dependencies.common_interfaces,
            .rosidl_generator = rosidl_generator_deps,
            .builtin_interfaces = rcl_interfaces_artifacts.builtin_interfaces,
            .service_msgs = rcl_interfaces_artifacts.service_msgs,
        },
        .{
            .rosidl_generator = rosidl_generator_build_deps,
        },
    );

    ros_libraries.actionlib_msgs = common_interfaces_artifacts.actionlib_msgs;
    ros_libraries.diagnostic_msgs = common_interfaces_artifacts.diagnostic_msgs;
    ros_libraries.geometry_msgs = common_interfaces_artifacts.geometry_msgs;
    ros_libraries.nav_msgs = common_interfaces_artifacts.nav_msgs;
    ros_libraries.sensor_msgs = common_interfaces_artifacts.sensor_msgs;
    ros_libraries.shape_msgs = common_interfaces_artifacts.shape_msgs;
    ros_libraries.std_msgs = common_interfaces_artifacts.std_msgs;
    ros_libraries.std_srvs = common_interfaces_artifacts.std_srvs;
    ros_libraries.stereo_msgs = common_interfaces_artifacts.stereo_msgs;
    ros_libraries.trajectory_msgs = common_interfaces_artifacts.trajectory_msgs;
    ros_libraries.visualization_msgs = common_interfaces_artifacts.visualization_msgs;

    ros_libraries.yaml = b.dependency("yaml", compile_args).artifact("yaml");
    // re export yaml so we can grab it directly from the zigros dependency later
    b.installArtifact(ros_libraries.yaml);

    const rcl_artifacts = rcl.buildWithArgs(
        b,
        compile_args,
        .{
            .upstream = upstream_dependencies.rcl,
            .rcutils = ros_libraries.rcutils,
            .yaml = ros_libraries.yaml,
            .rmw = ros_libraries.rmw,
            .tracetools = ros_libraries.tracetools,
            .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
            .rosidl_dynamic_typesupport = ros_libraries.rosidl_dynamic_typesupport,
            .rosidl_typesupport_interface = ros_libraries.rosidl_typesupport_interface,
            .rcl_logging_interface = ros_libraries.rcl_logging_interface,
            .type_description_interfaces = ros_libraries.type_description_interfaces,
            .service_msgs = ros_libraries.service_msgs,
            .builtin_interfaces = ros_libraries.builtin_interfaces,
            .rcl_interfaces = ros_libraries.rcl_interfaces,
        },
    );

    ros_libraries.rcl_yaml_param_parser = rcl_artifacts.rcl_yaml_param_parser;
    ros_libraries.rcl = rcl_artifacts.rcl;

    const cyclonedds = b.dependency("cyclonedds", compile_args).artifact("cyclonedds");
    // re export yaml so we can grab it directly from the zigros dependency later
    b.installArtifact(cyclonedds);

    ros_libraries.rmw_cyclonedds_cpp = rmw_cyclonedds.buildWithArgs(b, compile_args, .{
        .upstream = upstream_dependencies.rmw_cyclonedds,
        .rcutils = ros_libraries.rcutils,
        .tracetools = ros_libraries.tracetools,
        .cyclonedds = cyclonedds,
        .rcpputils = ros_libraries.rcpputils,
        .rmw = ros_libraries.rmw,
        .rmw_dds_common = ros_libraries.rmw_dds_common,
        .rmw_dds_common_interface = ros_libraries.rmw_dds_common_interface,
        .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
        .rosidl_runtime_cpp = ros_libraries.rosidl_runtime_cpp,
        .rosidl_typesupport_introspection_c = ros_libraries.rosidl_typesupport_introspection_c,
        .rosidl_typesupport_introspection_cpp = ros_libraries.rosidl_typesupport_introspection_cpp,
        .rosidl_typesupport_interface = ros_libraries.rosidl_typesupport_interface,
        .rosidl_dynamic_typesupport = ros_libraries.rosidl_dynamic_typesupport,
    });

    ros_libraries.libstatistics_collector = libstatistics_collector.buildWithArgs(b, compile_args, .{
        .upstream = upstream_dependencies.libstatistics_collector,
        .rcl = ros_libraries.rcl,
        .rcl_yaml_param_parser = ros_libraries.rcl_yaml_param_parser,
        .yaml = ros_libraries.yaml,
        .rcl_logging_interface = ros_libraries.rcl_logging_interface,
        .rcutils = ros_libraries.rcutils,
        .rmw = ros_libraries.rmw,
        .rosidl_dynamic_typesupport = ros_libraries.rosidl_dynamic_typesupport,
        .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
        .rosidl_typesupport_interface = ros_libraries.rosidl_typesupport_interface,
        .tracetools = ros_libraries.tracetools,
        .type_description_interfaces = ros_libraries.type_description_interfaces,
        .service_msgs = ros_libraries.service_msgs,
        .builtin_interfaces = ros_libraries.builtin_interfaces,
        .rcl_interfaces = ros_libraries.rcl_interfaces,
        .rcpputils = ros_libraries.rcpputils,
        .rosidl_runtime_cpp = ros_libraries.rosidl_runtime_cpp,
        .statistics_msgs = ros_libraries.statistics_msgs,
    });

    ros_libraries.ament_index_cpp = ament_index.buildWithArgs(b, compile_args);

    ros_libraries.rclcpp = rclcpp.buildWithArgs(b, compile_args, .{
        .upstream = upstream_dependencies.rclcpp,
        .rcl = ros_libraries.rcl,
        // .rcl_yaml_param_parser = ros_libraries.rcl_yaml_param_parser,
        // .rcl_logging_interface = ros_libraries.rcl_logging_interface,
        // .yaml = ros_libraries.yaml,
        // .rcutils = ros_libraries.rcutils,
        // .rmw = ros_libraries.rmw,
        // .rosidl_dynamic_typesupport = ros_libraries.rosidl_dynamic_typesupport,
        // .rosidl_runtime_c = ros_libraries.rosidl_runtime_c,
        // .rosidl_typesupport_interface = ros_libraries.rosidl_typesupport_interface,
        // .tracetools = ros_libraries.tracetools,
        .type_description_interfaces = ros_libraries.type_description_interfaces,
        .service_msgs = ros_libraries.service_msgs,
        .builtin_interfaces = ros_libraries.builtin_interfaces,
        .rcl_interfaces = ros_libraries.rcl_interfaces,
        .rcpputils = ros_libraries.rcpputils,
        .rosidl_runtime_cpp = ros_libraries.rosidl_runtime_cpp,
        .rosidl_typesupport_introspection_cpp = ros_libraries.rosidl_typesupport_introspection_cpp,
        .ament_index_cpp = ros_libraries.ament_index_cpp,
        .libstatistics_collector = ros_libraries.libstatistics_collector,
        .statistics_msgs = ros_libraries.statistics_msgs,
        .rosgrapg_msgs = ros_libraries.rosgraph_msgs,
    }, .{
        .python = python,
        .empy = python_libraries.empy,
        .rcutils = python_libraries.rcutils,
    });
}
