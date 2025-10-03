# ZigROS

Welcome to ZigROS!
ZigROS is an alternative build system for ROS2 utilizing the zig tool chain.
ZigROS prioritizes static, single executable builds and edge deployments.
Wrapping all the core C and C++ libraries, it greatly simplifies the ROS installation and deployment process by masquerading ROS2 as a single library.
Simply include ZigROS as a dependency in your build.zig.zon and start building.
No messing about with your package manager, ROS dep, or docker required.

ZigROS is suitable for building applications that depend on rcl or rclcpp.
This includes interface generation for c and c++.
Since the main goal of this project is static builds, python at runtime is out of scope.
Python at build time is still required since ROS relies heavily on empy for the code generation.
See the python section later on for more detail on how python is used.

This page gives a general overview of how to use ZigROS, for more information on the background and design of the project, [please head over to the docs folder.](docs)

# Usage

## Getting started

This assumes you have zig 0.15.1 installed on your system and an rclcpp ROS node to build.
The first few steps aren't any different from how you would typically build a C project with zig.
Start by adding a build.zig and a build.zig.zon file to the root of your ROS package.
Add ZigROS as a dependency in your build.zig.zon.
Add your ROS source files as an executable in the build.zig file.

Now onto the ZigROS specifics.
Behind the scenes ZigROS is building and generating code for dozens of ROS packages and their dependencies.
This is all hidden from the end user, and as long as you're building statically all that's needed is to include the rclcpp dependency, the RMW implementation (so far only cyclone is supported), and the logger implementation.


```zig
    const zigros_dep =
        b.dependency("zigros", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage,
            .@"system-python" = false,
        });
    // Ensure Lazy dependencies are all loaded
    if (b.graph.needed_lazy_dependencies.entries.len > 0) return;

    node.linkLibCpp();
    node.linkLibrary(zigros_dep.artifact("rmw_cyclonedds_cpp"));
    node.linkLibrary(zigros_dep.artifact("rcl_logging_spdlog"));
    node.linkLibrary(zigros_dep.artifact("rclcpp"));
```

The logger and DDS are typically runtime options, but with ZigROS's focus on static builds and deployments they are now compile time options.
ROS2 supports statically linked DDSs as long as the interface generation is only done with a single type support.
Multi typesupport / multi DDS support may be a future option, but would require additional glue to avoid calls to dlopen in the static build.
[There's more info on this in the design doc if interested.](docs/Design.md#how-does-zigros-statically-link-with-rclcpp)

There is also the option to link against only rcl with the `rcl` artifact.

For a simple single file node, your build.zig file would look something like this:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var pub_sub_node = b.addExecutable(.{
        .name = "node",
        .target = target,
        .optimize = optimize,
    });
    // Ensure Lazy dependencies are all loaded
    if (b.graph.needed_lazy_dependencies.entries.len > 0) return;

    pub_sub_node.linkLibCpp();
    pub_sub_node.linkLibrary(zigros_dep.artifact("rmw_cyclonedds_cpp"));
    pub_sub_node.linkLibrary(zigros_dep.artifact("rcl_logging_spdlog"));
    pub_sub_node.linkLibrary(zigros_dep.artifact("rclcpp"));

    // Add your node source files here
    pub_sub_node.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{"main.cpp"},
        .flags = &.{
            "--std=c++17",
            "-Wno-deprecated-declarations",
        },
    });

    b.installArtifact(pub_sub_node);
}

```

[See the example node in the examples directory to see this in action.](examples/example_node/build.zig)
If trying to use dynamic linking, additional dependencies need to be included by hand. 
The example build contains examples of this.

## Build arguments

Along with the typical build options, ZigROS introduces two more arguments.

**Linkage** allows you to specify if the libraries should be built statically or dynamically.
This will default to static.
Dynamic linking does work but is more experimental and generally considered out of scope for now as the focus is on single binary deployments.

**system-python** allows you to specify if the system python should be used instead of building python from source.
This defaults to false.
Setting this to true creates a system dependency on python and a few python packages, see the python section later on for details.

## Custom interfaces

Linking against rclcpp will get you the typical rcl interfaces.
Additionally ZigROS aims to provide all upstream interfaces out of the box.
If its missing an interface that's a normal upstream interface, PRs are welcome to fix this.
ZigROS packages all relevant interface files into a single library for easier consumption.
This means that the generated code from all three generator types needed for typsupport introspection are packaged into a single artifact.
See more details about this decision [in the devlog](docs/Devlog.md#2025-09-30-evaluating-installlibraryheaders-to-reduce-dependency-burden).

If your project uses custom interfaces, you can build them using zigros's wrappers for rosidl.

```zig

const zigros = @import("zigros");
//...
    var interface = zigros.createInterface(
        b,
        "zigros_example_interface",
        .{ .target = target, .optimize = optimize, .linkage = linkage },
    );

    interface.addInterfaces(b.path(""), &.{
        "msg/Example.msg",
        "srv/Example.srv",
    });

    // the example message uses the standard time message, so we must add builtin_interfaces as a dependency
    interface.addDependency("builtin_interfaces", zigros.ros_libraries.builtin_interfaces);
    // the example interface builds a service, so service_msgs is required
    interface.addDependency("service_msgs", zigros.extractInterface(zigros_dep, "service_msgs"));

    // or artifacts.c if you're only using rcl
    pub_sub_node.linkLibrary(interface.artifacts.cpp);
```

If you're creating a shared library or want this to function as an intermediate dependency, you can flag the interface for installation with `interface.installArtifacts();`.
This will install all generated artifacts.
Note that the generated libraries will not match the same structure as a typical ROS build as all generator output is combined into a single library.

This should be enough to get you going.
For a more in depth look at how to structure your project to best utilize ZigROS, please see the [how to structure your projcet](docs/Design.md#how-should-i-structure-my-project-to-best-utilize-zigros) section in the design doc.

# Missing features and roadmap

I plan on continuing to integrate core ROS functionality into ZigROS.
With that said this is being developed in parallel to rclzig and other zig-robotics projects, and I can't make commitments to a specific timeline.

## Features I hope to have ready for ZigROS 0.4
 - Actions
 - Remaining interfaces from rcl_interfaces
 - rosbag (at least a build of rosbag2_cpp for you to integrate with your projects manually, possibly some helpers around it)
 - foxglove-bridge (as an example of a 3rd party library, also as an easy way into your project in the absence of the ros cli)

## The following are features that I would welcome contributions for but can't/won't maintain on my own
 - windows support (would need to cross compile from linux which has some extra odd edge cases)
 - mac support (would also need to support cross compilation but should be more straight forward)
 - additional RMWs (for the single RMW use case only, see below)

## The following are concepts that would require new development (likely as separate repos)
 - A easy to use cli wrapper for launching variations of nodes
   - Could fit the use case where multi process is still required (bring up many instances of the same executable with different configs)
   - Could be a sort of replacement for the python launch system
 - Minimum RMW, an RMW that does the minimum amount of work to fulfill the intra process communication requirements, nothing more.
   - No idea if this is even possible or what it would take 
 - multi typesupport (would requre code or generator changes to avoid dlopen in the static case)
 - multi rmw implementations (would require code or generator changes to avoid dlopen in the static case)
   - This one likely isn't worth the hassle, deployments don't really use two RMWs at the same time, static linking a single RMW makes more sense.

# A note on Python

ROS uses python extensively for code generation.
To remove any dependency on the system, ZigROS defaults to building cpython and brings in all needed python dependencies.
This process is seamless and doesn't require anything form the user. 
The cpython build process will add a bit of time to the initial build, but after that the zig build system will keep it cached and there's no overhead.
However if you'd like to use the system version of python you can.
You'll require empy and lark as dependencies. 

# Conclusion

Thanks for reading this far!
If you'd like to do more reading, check out the docs folder.
It goes deeper into the background of this project, a bit on the design and why it's structured the way it is, along with other goodies.
Let me know if this project is interesting to you, I'm looking for other ROS developers or Zig fans to explore the merits and limitations to this alternative approach.
If there's enough interest, I'll organize a Zulip server for collaboration.

# Changelog

## 0.3.0
 - Updates to zig version 0.15.1
 - Adds common interfaces
 - [Update strategy for building to simplify linking and usage](docs/Devlog.md#2025-09-30-evaluating-installlibraryheaders-to-reduce-dependency-burden)
 - Build interfaces as a single library per language per interface (related to the above change)

## 0.2.0
 - Updates to zig version 0.14.0
 - [#1](https://github.com/zig-robotics/zigros/issues/1) Fix edge case when generating message names with a single trailing letter. 

## 0.1.0
Initial release. 
Supports building a minimal version of ROS up to rclcpp for topics and services.
