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
fn extractInterface(dep: *std.Build.Dependency, name: []const u8) RosidlGenerator.Interface {
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
    };
}

// The build/configure step sets this if its missing lazy deps which allows the ZigRos init call to return null if it's not set
var lazy_deps_needed = false;

pub const ZigRos = struct {
    ros_libraries: RosLibraries,
    python_libraries: PythonLibraries,
    python: zigros.PythonDep,
    type_description_generator: *Compile,
    adapter_generator: *Compile,
    code_generator: *Compile,

    // Will return null if lazy_deps_needed is set
    pub fn init(dep: *std.Build.Dependency) ?ZigRos {
        if (lazy_deps_needed) return null;
        const system_python = if (dep.builder.user_input_options.get(system_python_arg_name)) |option| switch (option.value) {
            .flag => true,
            .scalar => |s| std.mem.eql(u8, s, "true"),
            else => system_python_default,
        } else system_python_default;

        return ZigRos{
            .ros_libraries = .{
                .rcutils = dep.artifact("rcutils"),
                .rcpputils = dep.artifact("rcpputils"),
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
                .rosidl_dynamic_typesupport = dep.artifact("rosidl_dynamic_typesupport"),
                .rmw = dep.artifact("rmw"),
                .rmw_dds_common = dep.artifact("rmw_dds_common"),
                .rmw_dds_common_interface = extractInterface(dep, "rmw_dds_common"),
                .rcl_logging_interface = dep.artifact("rcl_logging_interface"),
                .rcl_logging_spdlog = dep.artifact("rcl_logging_spdlog"),
                .builtin_interfaces = extractInterface(dep, "builtin_interfaces"),
                .rosgraph_msgs = extractInterface(dep, "rosgraph_msgs"),
                .service_msgs = extractInterface(dep, "service_msgs"),
                .type_description_interfaces = extractInterface(dep, "type_description_interfaces"),
                .statistics_msgs = extractInterface(dep, "statistics_msgs"),
                .rcl_interfaces = extractInterface(dep, "rcl_interfaces"),
                .tracetools = dep.namedWriteFiles("tracetools").getDirectory(),
                .rcl_yaml_param_parser = dep.artifact("rcl_yaml_param_parser"),
                .yaml = dep.artifact("yaml"), // External
                .rcl = dep.artifact("rcl"),
                .rmw_cyclonedds_cpp = dep.artifact("rmw_cyclonedds_cpp"),
                .cyclonedds = dep.artifact("cyclonedds"), // External
                .libstatistics_collector = dep.artifact("libstatistics_collector"),
                .ament_index_cpp = dep.artifact("ament_index_cpp"),
                .rclcpp = dep.artifact("rclcpp"),
            },
            .python_libraries = .{
                .empy = if (!system_python) dep.builder.lazyDependency("empy", .{}).?.path("") else null,
                .lark = if (!system_python) dep.builder.lazyDependency("lark", .{}).?.path("") else null,
                .rcutils = dep.namedWriteFiles("rcutils").getDirectory(),
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
            },
            .python = if (!system_python)
                .{ .build = dep.builder.lazyDependency("python", python_build_args).?.artifact("cpython") }
            else
                .{ .system = system_python_exe },
            .type_description_generator = dep.artifact("type_description_generator"),
            .adapter_generator = dep.artifact("adapter_generator"),
            .code_generator = dep.artifact("code_generator"),
        };
    }

    pub fn linkRcl(self: ZigRos, module: *Module) void {
        module.linkLibrary(self.ros_libraries.rcutils);
        module.linkLibrary(self.ros_libraries.rcl);
        module.linkLibrary(self.ros_libraries.rmw);
        module.linkLibrary(self.ros_libraries.rcl_yaml_param_parser);
        module.linkLibrary(self.ros_libraries.yaml);
        self.ros_libraries.rcl_interfaces.linkC(module);
        self.ros_libraries.type_description_interfaces.linkC(module);
        module.linkLibrary(self.ros_libraries.rosidl_runtime_c);
        self.ros_libraries.service_msgs.linkC(module);
        self.ros_libraries.builtin_interfaces.linkC(module);
        module.addIncludePath(self.ros_libraries.rosidl_typesupport_interface);
        module.linkLibrary(self.ros_libraries.rosidl_dynamic_typesupport);
    }

    pub fn linkRclcpp(self: ZigRos, module: *Module) void {
        self.linkRcl(module);
        self.ros_libraries.rcl_interfaces.linkCpp(module);
        self.ros_libraries.type_description_interfaces.linkCpp(module);
        self.ros_libraries.service_msgs.linkCpp(module);
        self.ros_libraries.builtin_interfaces.linkCpp(module);
        self.ros_libraries.statistics_msgs.link(module);
        self.ros_libraries.rosgraph_msgs.link(module);

        module.addIncludePath(self.ros_libraries.tracetools);
        module.addIncludePath(self.ros_libraries.rosidl_runtime_cpp);
        module.linkLibrary(self.ros_libraries.rosidl_typesupport_introspection_cpp);
        module.linkLibrary(self.ros_libraries.libstatistics_collector);
        module.linkLibrary(self.ros_libraries.ament_index_cpp);
        module.linkLibrary(self.ros_libraries.rclcpp);
        module.linkLibrary(self.ros_libraries.rcpputils);
    }

    pub fn linkRmwCycloneDds(self: ZigRos, module: *Module) void {
        module.linkLibrary(self.ros_libraries.rmw_cyclonedds_cpp);
        module.linkLibrary(self.ros_libraries.cyclonedds);
    }

    pub fn linkLoggerSpd(self: ZigRos, module: *Module) void {
        module.linkLibrary(self.ros_libraries.rcl_logging_spdlog);
    }

    pub fn createInterface(
        self: ZigRos,
        b: *std.Build,
        name: []const u8,
        compile_args: zigros.CompileArgs,
    ) *RosidlGenerator {
        // TODO fix this. we need the correct python at some time
        return RosidlGenerator.create(
            b,
            name,
            .{
                .rosidl_runtime_c = self.ros_libraries.rosidl_runtime_c,
                .rosidl_runtime_cpp = self.ros_libraries.rosidl_runtime_cpp,
                .rosidl_typesupport_interface = self.ros_libraries.rosidl_typesupport_interface,
                .rosidl_typesupport_c = self.ros_libraries.rosidl_typesupport_c,
                .rosidl_typesupport_cpp = self.ros_libraries.rosidl_typesupport_cpp,
                .rosidl_typesupport_introspection_c = self.ros_libraries.rosidl_typesupport_introspection_c,
                .rosidl_typesupport_introspection_cpp = self.ros_libraries.rosidl_typesupport_introspection_cpp,
                .rcutils = self.ros_libraries.rcutils,
            },
            .{
                .python = self.python, // TODO not sure how to get the correct python;
                .empy = self.python_libraries.empy,
                .lark = self.python_libraries.lark,
                .rosidl_cli = self.python_libraries.rosidl_cli,
                .rosidl_adapter = self.python_libraries.rosidl_adapter,
                .rosidl_parser = self.python_libraries.rosidl_parser,
                .rosidl_pycommon = self.python_libraries.rosidl_pycommon,
                .rosidl_generator_type_description = self.python_libraries.rosidl_generator_type_description,
                .rosidl_generator_c = self.python_libraries.rosidl_generator_c,
                .rosidl_generator_cpp = self.python_libraries.rosidl_generator_cpp,
                .rosidl_typesupport_c = self.python_libraries.rosidl_typesupport_c,
                .rosidl_typesupport_cpp = self.python_libraries.rosidl_typesupport_cpp,
                .rosidl_typesupport_introspection_c = self.python_libraries.rosidl_typesupport_introspection_c,
                .rosidl_typesupport_introspection_cpp = self.python_libraries.rosidl_typesupport_introspection_cpp,
                .type_description_generator = self.type_description_generator,
                .adapter_generator = self.adapter_generator,
                .code_generator = self.code_generator,
            },
            compile_args,
        );
    }
};

const system_python_default = false;
const system_python_arg_name = "system-python";
const system_python_exe = "python3";
const python_build_args = .{ .optimize = .ReleaseFast };

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
        const py = b.lazyDependency("python", python_build_args);
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
        .{
            .rosidl_generator = rosidl_generator_build_deps,
        },
    );

    ros_libraries.builtin_interfaces = rcl_interfaces_artifacts.builtin_interfaces;
    ros_libraries.rosgraph_msgs = rcl_interfaces_artifacts.rosgraph_msgs;
    ros_libraries.service_msgs = rcl_interfaces_artifacts.service_msgs;
    ros_libraries.type_description_interfaces =
        rcl_interfaces_artifacts.type_description_interfaces;
    ros_libraries.statistics_msgs = rcl_interfaces_artifacts.statistics_msgs;
    ros_libraries.rcl_interfaces = rcl_interfaces_artifacts.rcl_interfaces;

    ros_libraries.tracetools = ros2_tracing.build(b);

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
        .rcl_yaml_param_parser = ros_libraries.rcl_yaml_param_parser,
        .rcl_logging_interface = ros_libraries.rcl_logging_interface,
        .yaml = ros_libraries.yaml,
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
