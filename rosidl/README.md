# Zig package for rosidl and rosidl_typesupport

This provides a zig package for the ROS2 rosidl project, as well as some zig helpers to streamline
interface generation within the zig build system. This currently targets zig 0.14 and ROS Jazzy.

It also includes the rosidl_typesupport and rosidl_dynamic_typesupport repo since they also use the
same style of generators and depend largely on rosidl.

## TODO

### Missing ROS features
 - Action generation
 - Multi typesupport support, currently this only generates the introspection type support required
   for cyclone

https://github.com/ros2/rosidl/tree/jazzy
https://github.com/ros2/rosidl_typesupport/tree/jazzy
