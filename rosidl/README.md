# Zig package for rosidl and rosidl_typesupport

This provides a zig package for the ROS2 rosidl project, as well as some zig helpers to streamline
interface generation within the zig build system. This currently targets zig 0.15 and ROS Jazzy.

It also includes the rosidl_typesupport and rosidl_dynamic_typesupport repo since they also use the
same style of generators and depend largely on rosidl.

## Modifications

Note that instead of multiple libraries being built, a single library per language is compiled 
instead. Each code generator is still run, but the output code is all built into a single library. 
For example, the rosidl_generator_c, rosidl_typesupport_c, and rosidl_typesupport_introspection_c 
are all combined into a single {name_of_interface}_c library. This simplifies what needs to be 
included when working with interfaces, as well as solves the issue of rosidl_generator_cpp only 
generating header files which zig doesn't have a great way to handle. Given that ZigROS targets 
static compilation, there's no real downside to this, as there's never really a case where only 
a subset of the generated code is needed. All used code is known at compile time.

## TODO

### Missing ROS features
 - Action generation
 - Multi typesupport support, currently this only generates the introspection type support required
   for cyclone

https://github.com/ros2/rosidl/tree/jazzy
https://github.com/ros2/rosidl_typesupport/tree/jazzy
