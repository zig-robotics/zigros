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

All of the above message libraries will automatically be included and linked when calling
`zigros.linkRcl()` and `zigros.linkRclCpp()`.
