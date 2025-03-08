# Background

Background is broken out into two sections providing perspectives for both ROS and zig.
Please read both sections even if you're familiar with one or the other.

## I come from a ROS background, why zig?

[Zig](https://ziglang.org/) is a general-purpose programming language and tool chain for maintaining robust, optimal and reusable software.
ZigROS is focused on the tool chain side of things, though if interested a zig client library is also in the works.
The zig build system wraps clang/llvm and natively supports building C and C++.
Zigs big claim to fame in this space is effortless cross compilation, sane defaults, and zero dependencies outside of the compiler.

Lets have a look at what it takes to build ROS via zig.
The following script downloads zig and an example node using ZigROS builds it, then runs it.

```sh
wget -qO- https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz | tar xJv
wget -qO- https://github.com/zig-robotics/rclcpp_example/archive/refs/heads/main.tar.gz | tar xzv
cd rclcpp_example-main; ../zig-linux-x86_64-0.14.0/zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl --summary none  
./zig-out/bin/node
```

That's it, you now have a fully functional ROS node running.
Notice that there's no mention of *any* dependency requirements outside of zig.
ZigROS embraces the "install it from source" ideology that is generally used in the zig community.
Zigs creator gave a talk on this if interested: [Zig Build System & How to Build Software From Source](https://www.youtube.com/watch?v=wFlyUzUVFhw).
Notice as well that we're building against musl for a fully static executable.
Static builds make sense when targeting deployments.

To demonstrate both the zero dependency requirements and fully static builds [see the alpine dockerfile in the examples directory](../examples/docker/alpine.Dockerfile).
Note that this dockerfile is provided for demonstration purposes only, I encourage you to embrace the build it from source attitude and avoid docker all together.

A few other highlights of the zig build system includes cross compilation.
If you're ready to deploy to an embedded target, typically you need an arm build.
That comes for free with zig, simply change the triplet from x86_64 to aarch64 or any other architecture.

Similarly if you're worried about potential down sides of musl, you can build against glibc still by changing musl to gnu.
This will statically link everything except libc.
[See the debian dockerfile for a demonstration of this](../examples/docker/debian.Dockerfile).
If you want a specific linux or libc version, specify them as part of the target (for example `aarch64-linux.6.11.5-gnu.2.36`).
In theory this works for different OSs like windows and mac but those aren't supported (yet) in ZigROS.

## I come from a Zig background, why ROS?

ROS, short for Robot Operating System, is an open source project providing libraries and tooling for building robotics applications.
It's also by far the largest open source community for robotics with several dedicated conferences around the world every year, and lots of academic and industry support.
The general goal of ROS is to provide abstractions to common robotics building blocks to accelerate the development of robotics applications.
[From wikipedia](https://en.wikipedia.org/wiki/Robot_Operating_System#Early_days_at_Stanford_(2007_and_earlier)): "While working on robots to do manipulation tasks in human environments, the two students noticed that many of their colleagues were held back by the diverse nature of robotics: an excellent software developer might not have the hardware knowledge required, someone developing state of the art path planning might not know how to do the computer vision required."

The core ROS libraries provide a middle ware to develop what they call "ROS Nodes" which will generally encapsulate a single robotic function.
Nodes communicate to other nodes through "ROS interfaces" with ether a pub sub pattern called "ROS topics", a request response pattern called "ROS services", or long running requests called "ROS actions".
This allows for developers to abstract specific robotics functionalities.
For example ROS nodes can be developed for sensor drivers where each image sensor produces a ROS image message.
This allows for my downstream nodes to consume the abstract ROS image message, allowing you to swap out different cameras without needing to change any of the downstream nodes.
This pattern is repeated for other functions like motion planning, control etc.

The underlying messaging is abstracted through what ROS calls the "ROS Middle Ware"(RMW).
The typical RMW is implemented with [DDS](https://www.omg.org/omg-dds-portal/) under the hood, though there are other middle wares available.
By default, DDS is network centric, which has the side effect that you can write your ROS nodes in different languages.
ROS support for specific libraries are generally provided by wrapping the core "ROS client library" c package.
There's two official languages supported by the core ros team, C++ provided with rclcpp, and python provided with rclpy.
Zig robotics plans to offer a zig ROS client library in the near future.

ROS despite its name does not provide an operating system, however it's typical installation and use cases tightly integrate at the OS level.
The typical development process involves the developers installing specific supported linux distros and adding additional ROS repos.
Deployments commonly follow this same pattern as well with installing a specific flavor of ubuntu onto an industrial edge PC or embedded linux device.

ROS is also created with simulation in mind. The node / topic based structure makes swapping out data sources trivial.
You can switch between a real driver node, simulated nodes, or replaying data all with minimal impacts to your abstracted software stack.
Most popular simulators out there will support running with ROS.
The gazebo simulator in particular is developed in close conjunction with ROS.
ROS has the option of abstracting time so that it can be provided from the simulator.
This allows for simulations that run faster or slower than real time depending on what you're after.
The node / topic structure is also great for logging.
ROS ships with extensive logging tooling called rosbags.

If interested in learning more about ROS, the [nav2 example is a good starting point showcasing a realistic deployment of ROS.](https://docs.nav2.org/getting_started/index.html#running-the-example) 

