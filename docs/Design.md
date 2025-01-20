# Design

This document attempts to provide some insights for why things ended up the way they did.
This project started off as a side project to a ros client library I was developing for ROS.
Fed up with the normal ways to work with ros (an OS level installation, docker, or a massive colcon workspace to deal with ROS's tremendous dependency creep) I set out to see if it'd be possible to use the zig build system to build all the rcl dependencies.
When this ended up working reasonably well, I felt like I may have stumbled onto something actually useful.
To make it useful to a wider audience, I decided to add rclcpp support.

There was really no grand design ahead of building this project, so instead of a formal design doc I structured this more as a Q&A which poses some of the bigger design decisions I landed on as questions.

## Why a mono repo?

Initially all packages got their own repo and equivalent zig package.
These repos are still available on the zig-robotics github if you're interested but they will not be maintained and eventually taken down.
There were two main issues that the individual package approach ran into.

The first was synchronizing versions.
Zig takes the more modern approach to package management and uses the explicit version provided in a packages own build.zig.zon file.
This does work for actual zig projects where code is effectively all self contained and baked in.
The trouble is that ZigROS is only building C/C++ packages. 
In the C world, there can generally only be one version of the dependency due to linking requirements and symbol constraints in the final binary. 
What this means is that whenever you have a package dependency tree like A is a base package that both B and C depend on, and your final executable links against both B and C, B and C need to use the same version as your executable can only be linked against one version of A.
Keeping the version that B and C depend on in sync is a real pain when they're in totally separate repos.
ROS has this style of dependency tree in many places.
Keeping everything in a mono repo means that all the upstream ROS packages use a single version, and the [ZigROS build.zig.zon](../build.zig.zon) file is the single source of truth when it comes to package versions.

The second issue was related to the first, in that the zig build system does not have a way to export dependencies downstream.
That is to say, if you want to link against rclcpp, you also need to link against all of rclcpps dependencies separately.
While possible to extract dependencies from a parent package, you still need to do this by hand or with recursive helper functions that are tedious to write. (naive implementations end up producing too many command line argument errors, maybe I'll make a blog post about this in the future.)

A mono repo solves both these problems by providing a single source for defining your entire ROS environment, and allowing for simpler helpers when it comes time to link.
There's a few byproducts of this as well that I like.
The main one as mentioned is that it effectively takes the operating system out of ROS.
The single ZigROS dependency *feels* like a single library.

## Why the odd structure of build.zig files in subdirectories?

This is the compromise made between a mono repo and separate packages.
Each ROS package for the most part gets its own subdirectory and its own build.zig file.
This was originally to simplify moving from the fragmented package style, but was left in as an easy way to separate out what would otherwise be a very large single build.zig file.
This also would allow for someone to revert back to individual packages relatively easily, or provide a way to build individual packages by running build commands in the subdirectory of choice.
To do this, all that needs to be added is a build.zig.zon that includes all of the dependencies (either paths to the parent directory or to your own hosted individual packages) and adding back in a `build` function that calls the `buildWithArgs` function with the locally sourced dependencies.
I may even add that in as a way to streamline testing building individual packages. 

## How do I work with this repo? / embracing flat dependencies

Given that this repo is attempting to solve issues with hierarchal builds, it is not recommended to use ZigROS in a way that can similarly fragment.
What this means is that you should not have separate instances of ZigROS showing up in multiple build.zig.zon files for any given project.
This is inline with the overall philosophy of the project, targeting single executable compilations.

### Some suggestions then on how to use ZigROS in your own project

**A single dependency in your own mono repo:**
Say you have a traditional ROS workspace full of your own custom nodes and interfaces.
Keep that ROS workspace as is and commit it as a mono repo.
Build all your ROS packages at the top level with a single build.zig file controlling everything and a single build.zig.zon file that pulls in ZigROS.
This is ideal if ZigROS already provides all the functionality you need and you do not need to extend it.
Note that if there's still desire to have your packages be separate repos your "mono repo" could look a lot like the zigros mono repo where it only tracks the zig build files and the underlying ROS nodes are left as standard ROS repos and brought in individually with the build.zig.zon file. 

**Fork it:**
Fork this repo and add your code along side this repo and extend the existing build.zig file.
This gives you easier access to the internals and can more easily have precise control over linking or modify how the core ROS packages are being built.

**Submodule it:**
Include ZigROS as a submodule in your ros workspace and point to it using the .path option in your build.zig.zon.
This would allow you to compose other ZigROS repos with the minimal number of changes.
Fork and submodule each individual repo that already has ZigROS as a dependency.
The only change in your fork of of the upstream code would be to modify the build.zig.zon and point it to the correct ZigROS

Each one of these options results in a single instance of ZigROS being used.
While this adds a bit of complexity, it ensures that there aren't duplicate definitions of the dependency that can go out of sync.
It is technically possible to run with multiple independent ZigROS dependencies if you're extremely careful to keep the versions the same, but this isn't recommended.

### 3rd party ROS projects

If you've created a ZigROS build for additional open source ROS project, contributions to this repo would be welcome.
The idea would be larger projects like Nav2 or MoveIt could also have build scripts in this repo, simplifying integration into other projects.

## How should I structure my project to best utilize ZigROS?

"But zig robotics" you ask, "I have many ROS nodes, won't building them all separately result in a bunch of bloated binaries?".
Short answer is yes, the longer answer is it depends.

### Sidebar, a quick analysis of baseline ROS size

It's no secret that ROS is a large set of libraries.
If you pull the Jazzy docker image you'll find its nearly 900 Mb.
This however includes all the bloat that comes with python, among other things.
There's an [additional example docker](../examples/docker/base-ros-install.Dockerfile) file that builds the minimal packages required for an rclcpp node as shared libraries.
Building this we can see that a bare bones, fully dynamic install is just over 200Mb.
Building the base example node and statically linking with musl results in a binary around 4Mb.
This works because the static library is able to remove unused code.
As your node uses more of the ROS functionality, this size and therefore repeated size between executables will increase.

### The actual intended solution: single executable deployments

ROS is extremely dynamic in nature, almost to a fault.
Out of the box each node is generally its own process, and relies on the RMW which is dynamically loaded.
This is handy when you're first getting started, but doesn't scale; particularly on resource constrained edge hardware.
Practically all large ROS projects reach a point where the RMW can't handle the number of nodes used in a system.
The most common solution to this is [node composition](https://docs.ros.org/en/jazzy/Concepts/Intermediate/About-Composition.html).
Node composition is a concept that lives in the rclcpp layer rather than the core rcl.
It allows you to instantiate multiple nodes within a single executable.
This allows the RMW to take shortcuts for intra process interfaces, or if configured correctly for rclcpp to skip the RMW entirely.
This lets the node skip serialization and enables zero copy pipelines to be constructed in the best case, and minimal copy in the worst case.

This is the approach that underpins the usefulness of single executable deployments.
For static executables a particular flavour of node composition is required.
There's generally two approaches.
Following ROS's default of dynamically loading things, the "recommended" version is registering your node as a component, and using another node called a component manager to load nodes at runtime.
This of course isn't static build friendly.
[There's a second option though where nodes are simply constructed in a bespoke executable.](https://docs.ros.org/en/jazzy/Tutorials/Intermediate/Composition.html#compile-time-composition-with-hardcoded-nodes)
On top of being static build friendly, it also gives you full control over the execution structure.
You want to mix executor types? Go for it.
You want many nodes in the same executor? You got it.
You want to bring your nodes up in a specific controlled order without needing the overhead of 4 additional services per node and using an entirely different base node implementation? You get that for free!
I digress. 
For a simple example of this form of node composition with ZigROS [see the the rclcpp example repo.](https://github.com/zig-robotics/rclcpp_example)


### How do I interact with my system without the ROS CLI?

The ROS CLI is unfortunately all python based.
This means integrating it into a static binary with the rest of your ROS system isn't realistic.
With that said, nothing prevents you from interacting with a single executable deployment externally.
This means that if you have a networking connection into your edge device and the correct RMW configuration, running any of the standard ROS tools still work.
Keep in mind that this will reduce much of the performance gains to be had with single executable deployments, as it brings back the networking portion of the RMW back into the loop. 
If particular interactivity is required on your edge device, its suggested to build this in as functionality. 
Other C++ based diagnostics tooling like logging with rosbags or something like the foxglove bridge are already composable.
Builds for both these packages are on the ZigROS TODO. 


### How does ZigROS statically link with RCLCPP?

RCLCPP has four major library components, the core RCL package, the RMW, ROSIDL/message generation, and the RCL logger.

The out of the box [RMW is actually a shim that calls dl open](https://github.com/ros2/rmw_implementation/tree/jazzy/rmw_implementation) (or your OS equivalent) and redirects RMW calls to a middle ware selected at runtime.

When ROSIDL generates its message types it must know at code gen time which type supports are to be included, and these are baked into the underlying typesupport library.
They are not baked in as direct calls however since their symbols would collide.
Instead, the library names get baked into the type support .so [and dlopen is used to load the reqested library](https://github.com/ros2/rosidl_typesupport/blob/jazzy/rosidl_typesupport_c/src/type_support_dispatch.hpp)
Here's an excerpt from the baked "dynamic" libraries `rosidl_typesupport_c/builtin_interfaces/msg/time__type_support.cpp`:
```c++
typedef struct _Time_type_support_ids_t
{
  const char * typesupport_identifier[2];
} _Time_type_support_ids_t;

static const _Time_type_support_ids_t _Time_message_typesupport_ids = {
  {
    "rosidl_typesupport_fastrtps_c",  // ::rosidl_typesupport_fastrtps_c::typesupport_identifier,
    "rosidl_typesupport_introspection_c",  // ::rosidl_typesupport_introspection_c::typesupport_identifier,
  }
};

```
You read that correctly.
All available typesupports must be known *at code generation time*, before compile time even, and still we need to deal with dlopen.

The rcl logger is the least controversial, and is simply an interface for an otherwise normally linked library and is trivial to switch to static.

Even [RCLCPP itself relies on dlopen](https://github.com/search?q=repo%3Aros2%2Frclcpp%20sharedlibrary&type=code), luckily at least for now its only used for generic interfaces (as in, interfaces that are not known at compile time).
This use case doesn't make sense for single executable binaries thankfully, but may limit the deployment of some libraries.

The reliance on dlopen may make static executables seem like a non starter.
In the case of the RMW, building and linking against an rmw directly instead of rmw_implementation is straight forward.
The ROSIDL case may seem harder on the surface, but thankfully there's an out.
While [the default RMW rmw_fastrtps_cpp](https://github.com/ros2/rmw_fastrtps/tree/jazzy/rmw_fastrtps_cpp) requires two type supports for some reason, other RMWs require only one.
ZigROS is built around cyclone dds which relies only on the default `rosidl_typesupport_introspection` typesupport.
In theory other single type support middle wares would work too like `rmw_fastrtps_dynamic_cpp` but builds are not provided at this time (PRs are welcome).
The single type support is significant due to an undocumented feature in the [rosidl typesupport generator as old as ROS2 itself](https://github.com/ros2/rosidl_typesupport/blob/63536214620a4bc21920840b07fc457086e3abc1/rosidl_typesupport_c/resource/msg__type_support.cpp.em#L138).
![single typesupport](images/single_typesupport.png)

If only a single typesupport is provided, that typesupport is provided directly, bypassing dlopen entirely!

This means that it is impossible to use the default ROS installation statically, and adds complications to anything that might be single typesupport *other* than typesupport introspection.
For example, the new [rmw zenoh appears to be single type support, but depends on typesupport fastrtps](https://github.com/ros2/rmw_zenoh/blob/jazzy/rmw_zenoh_cpp/CMakeLists.txt#L21-L22) instead of introspection.
This on the surface makes it a single type support library, however some tooling like [rosbag2 depends on typesupport introspection directly](https://github.com/ros2/rosbag2/blob/jazzy/rosbag2_cpp/CMakeLists.txt#L54).
In theory this forces you into a multi typesupport system if you want to run zenoh and use rosbag, but I haven't experimented with that yet. 
