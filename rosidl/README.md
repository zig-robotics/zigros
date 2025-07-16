# Zig package for rosidl and rosidl_typesupport

This provides a zig package for the ROS2 rosidl project, as well as some zig helpers to streamline
interface generation within the zig build system. This currently targets zig 0.14 and ROS Jazzy.

It also includes the rosidl_typesupport and rosidl_dynamic_typesupport repo since they also use the
same style of generators and depend largely on rosidl.

## Additions

Note that in addition to the usual individual packages, a single library per language is also generated.
This is for convineince within the zig build system as zig doesn't support "header only" libraries
well. What this means is that if you want to continue to use each individual library (specifically 
rosidl_generator_c, rosidl_typesupport_c, rosidl_typesupport_cpp, rosidl_typesupport_introspection_c, 
rosidl_typesupport_introspection_cpp, and the header only rosidl_generator_cpp which zigros treats
as a named write file due to the lack of header only libraries) you can, but frankly its rare that
you'll ever use just one, so as a convenience an additional combined artifact is generated. This
combined artifact also re-exports (install dependency headers and libraries) all its dependencies 
so you don't have to worry about specifying them. (the individual libraries do not export their 
dependencies, this allows you to be very picky with what gets included in your final binary if
you're being paranoid enough to use the individual libraries still). Using this combined library 
shouldn't introduce much overhead in compiling. Note this has really only been tested with static
builds, your millage may vary building dynamically.

Note that in the long run building the individual libraries may eventually be dropped in favor of
this individual library approach for simplicity. Fewer libraries play nicer with the zig build 
system, and formal binary compatibility with ROS built from other sources is not a goal of the
project.

## TODO

### Missing ROS features
 - Action generation
 - Multi typesupport support, currently this only generates the introspection type support required
   for cyclone

https://github.com/ros2/rosidl/tree/jazzy
https://github.com/ros2/rosidl_typesupport/tree/jazzy
