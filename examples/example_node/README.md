# ZigROS rclcpp example

This repo contains an example C++ node built with zig and ZigROS.
It showcases the suggested single executable use case for ZigROS by writing nodes as libraries and composing them by hand into a single executable.

Checkout the ZigROS repo for a more in depth intro to the ZigROS library.

## How to build

The only dependency this repo has is on the zig compiler.
Make sure you have zig 0.14 available on your system, then simply build with:

```
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl
```

Then run with

```
./zig-out/bin/node
```

The build.zig file shows some suggested build tricks, such as stripping the binary if not in debug mode, and setting the section flags if building with the release small flag. 

