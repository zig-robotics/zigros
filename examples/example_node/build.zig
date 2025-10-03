const std = @import("std");
const zigros = @import("zigros");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Specify static or dynamic linkage",
    ) orelse .static;

    var pub_sub_node = b.addExecutable(.{
        .name = "node",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = if (optimize == .Debug) false else true,
        }),
    });

    pub_sub_node.want_lto = true;

    //  The core ZigROS libraries will also set these flags if ReleaseSmall is used.
    if (optimize == .ReleaseSmall) {
        pub_sub_node.link_function_sections = true;
        pub_sub_node.link_data_sections = true;
        pub_sub_node.link_gc_sections = true;
    }

    const zigros_dep =
        b.dependency("zigros", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage,
            .@"system-python" = false,
        });
    // Ensure Lazy dependencies are all loaded
    if (b.graph.needed_lazy_dependencies.entries.len > 0) return;

    pub_sub_node.linkLibCpp();
    pub_sub_node.linkLibrary(zigros_dep.artifact("rmw_cyclonedds_cpp"));
    pub_sub_node.linkLibrary(zigros_dep.artifact("rcl_logging_spdlog"));
    pub_sub_node.linkLibrary(zigros_dep.artifact("rclcpp"));
    // The following isn't needed if you're only building statically
    // This seems to be a bug in dynamic library handling of zig, in that linking a .so does not bring along its own dependencies
    // This means we need to continue to include dependent .so files that get hit by the executable
    // The main goal of the zigros project is to provide easy static builds so troubleshooting this has been left to the user
    // PRs to fix dynamic libraries are welcome
    if (linkage == .dynamic) {
        pub_sub_node.linkLibrary(zigros_dep.artifact("rcl_logging_interface"));
        // This seems extra cursed but couldn't seem to get linking spdlog against only the final exe to work
        var rcl = zigros_dep.artifact("rcl");
        rcl.linkLibrary(zigros_dep.artifact("rcl_logging_spdlog"));

        pub_sub_node.linkLibrary(zigros_dep.artifact("rcl"));
        pub_sub_node.linkLibrary(zigros_dep.artifact("rcutils"));
        pub_sub_node.linkLibrary(zigros_dep.artifact("rmw"));
        pub_sub_node.linkLibrary(zigros_dep.artifact("libstatistics_collector"));
        pub_sub_node.linkLibrary(zigros_dep.artifact("statistics_msgs_cpp"));
    }

    pub_sub_node.addIncludePath(b.path("include"));
    pub_sub_node.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "main.cpp",
            "subscription.cpp",
            "publisher.cpp",
            "service.cpp",
        },
        .flags = &.{
            "--std=c++17",
            "-Wno-deprecated-declarations",
        },
    });

    var interface = zigros.createInterface(
        zigros_dep,
        b,
        "zigros_example_interface",
        .{ .target = target, .optimize = optimize, .linkage = linkage },
    ) orelse return; // return early if lazy deps are needed
    interface.addInterfaces(b.path(""), &.{
        "msg/Example.msg",
        "srv/Example.srv",
    });

    // the example message uses the standard header message, so we must add builtin_interfaces as a dependency
    interface.addDependency("builtin_interfaces", zigros.extractInterface(zigros_dep, "builtin_interfaces"));
    // the example interface builds a service, so service_msgs is required
    interface.addDependency("service_msgs", zigros.extractInterface(zigros_dep, "service_msgs"));

    pub_sub_node.linkLibrary(interface.artifacts.cpp);

    b.installArtifact(pub_sub_node);
    if (linkage == .dynamic) {
        interface.installArtifacts();
    }
}
