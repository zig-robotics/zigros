# Zig package for ROS2 Common Interfaces

This builds the common_interfaces from ROS2:

- actionlib_msgs
- diagnostic_msgs
- geometry_msgs
- nav_msgs
- sensor_msgs
- shape_msgs
- std_msgs
- std_srvs
- stereo_msgs
- trajectory_msgs
- visualization_msgs

To utilize the libraries in your build, call `zigros.ros_libraries.sensor_msgs.link(your_exe.root_module)`.
You will also need to manually specify any interface dependencies.
Dependency management is still being sorted out.

