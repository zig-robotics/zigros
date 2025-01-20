# Docker examples

These dockerfiles are provided as examples to demonstrate and test the zero external dependency goal of ZigROS.
Do not use them for development.

These examples build the [ZigROS example project which brings in ZigROS as a dependency.](https://github.com/zig-robotics/rclcpp_example)

To build, run:
```
docker build -t test-zig -f ./alpine.Dockerfile .
```
or
```
docker build -t test-zig -f ./debian.Dockerfile .
```
or
```
docker build -t test-zig -f ./base-ros-install.Dockerfile .
```

The alpine dockerfile demonstrates fully static compilation, the debian dockerfile demonstrates static builds but still using glibc.
The base ros install is more to demonstrate the smallest possible install of a shared library build of ROS.
The way this is implemented is inefficient and would require ZigROS to support re exporting the underlying ROS install to work properly.
