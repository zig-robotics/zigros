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

This assumes you have zig 0.14.0 installed on your system and an rclcpp ROS node to build.
The first few steps aren't any different from how you would typically build a C project with zig.
Start by adding a build.zig and a build.zig.zon file to the root of your ROS package.
Add ZigROS as a dependency in your build.zig.zon.
Add your ROS source files as an executable in the build.zig file.

Now onto the ZigROS specifics.
Behind the scenes ZigROS is building and generating code for dozens of ROS packages and their dependencies.
Because of this there needs to be a dedicated initialize step that looks like:

```zig
    const zigros = ZigRos.init(b.dependency("zigros", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage, // optional, will default to static
        .@"system-python" = false, // optional, will default to false
    })) orelse return; // return early if lazy deps are needed
```

This will return a zigros object with helpers for linking, or null if one or more of its lazy dependencies are missing.
In the case where it returns null, the standard guidelines apply for missing lazy dependencies.
The only reason to finish the configure step is to find other lazy dependencies.
If your project doesn't also have lazy dependencies, simply returning at this point is fine. 

You can then link your standard node executable with:

```zig
    zigros.linkRclcpp(&pub_sub_node.root_module); // Link rclcpp
    zigros.linkRmwCycloneDds(&pub_sub_node.root_module); // link your dds of choice
    zigros.linkLoggerSpd(&pub_sub_node.root_module); // link your logger of choice
```

Here the general pattern is:
 1. link rclcpp
 2. link your DDS of choice (for now only cyclone is supported)
 3. link your logger of choice (for now only spdlog is supported)

The logger and DDS are typically runtime options, but with ZigROS's focus on static builds and deployments they are now compile time options.
ROS2 supports statically linked DDSs as long as the interface generation is only done with a single type support.
Multi typesupport / multi DDS support may be a future option, but would require additional glue to avoid calls to dlopen in the static build.
[There's more info on this in the design doc if interested.](docs/Design.md#how-does-zigros-statically-link-with-rclcpp)

There is also the option to link against only rcl with `zigros.linkRcl`.

For a simple single file node, your build.zig file would look something like this:
```zig
const std = @import("std");

const ZigRos = @import("zigros").ZigRos;

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
        .target = target,
        .optimize = optimize,
        .strip = if (optimize == .Debug) false else true, // for tiny binaries
    });

    const zigros = ZigRos.init(b.dependency("zigros", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .@"system-python" = false,
    })) orelse return; // return early if lazy deps are needed

    pub_sub_node.linkLibCpp();
    zigros.linkRclcpp(&pub_sub_node.root_module);
    zigros.linkRmwCycloneDds(&pub_sub_node.root_module);
    zigros.linkLoggerSpd(&pub_sub_node.root_module);

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

[See the example repo to see this in action.](https://github.com/zig-robotics/rclcpp_example)

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
If your project uses custom interfaces, you can build them using zigros's wrappers for rosidl.

```zig
    var interface = zigros.createInterface(
        b,
        "zigros_example_interface",
        .{ .target = target, .optimize = optimize, .linkage = linkage },
    );

    interface.addInterfaces(b.path(""), &.{
        "msg/Example.msg",
        "srv/Example.srv",
    });

    // the example message uses the standard time message, so we must add builtin_interfaces
    // as a dependency
    interface.addDependency("builtin_interfaces", zigros.ros_libraries.builtin_interfaces);
    interface.artifacts.linkCpp(&pub_sub_node.root_module);
```

If you're creating a shared library or want this to function as an intermediate dependency, you can flag the interface for installation with `interface.installArtifacts();`.
This will install all generated artifacts typically associated with a ROS interface.

This should be enough to get you going.
For a more in depth look at how to structure your project to best utilize ZigROS, please see the [how to structure your projcet](docs/Design.md#how-should-i-structure-my-project-to-best-utilize-zigros) section in the design doc.

# Missing features and roadmap

I plan on continuing to integrate core ROS functionality into ZigROS.
With that said this is being develped in parallel to rclzig and other zig-robotics projects, and I can't make commitments to a specific timeline.

## Features I hope to have ready for ZigROS 0.3
 - Actions
 - Remaining interfaces from rcl_interfaces
 - All interfaces from common_interfaces
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

## 0.2.0
 - Updates to zig version 0.14.0
 - [#1](https://github.com/zig-robotics/zigros/issues/1) Fix edge case when generating message names with a single trailing letter. 

## 0.1.0
Initial release. 
Supports building a minimal version of ROS up to rclcpp for topics and services.
