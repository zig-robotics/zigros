# 2025-09-30 Evaluating installLibraryHeaders to reduce dependency burden

One of the goals of ZigRos is to highlight the rather large dependency graph that ROS requires.
In my initial efforts, ZigRos embraced a strict "link all dependencies" approach, forcing the user 
to manually specify every package rcl and rclcpp required. The goal was to introduce some 
intentional friction as a sort of call out for ROS design decisions that seem odd to me. ROS leans
too into micro dependencies in my opinion, particularly for rosidl and interfaces.

This friction quickly proved too much, and helper functions were added to link the required 
dependencies. `linkRcl`, `linkRclcpp`, etc. Notably though, these still linked all individual
dependencies. This change explores replacing this with simply using the 
`installLibraryHeaders` function from the zig build system to export all underlying dependencies.
To avoid a cascading issue of headers from common libraries like `rcutils` being copied many times
over, only rcl, rclcpp, spdlog, and cyclonedds get this treatment. This means you can now link 
directly to the rcl or rclcpp artifacts, and all dependencies come along for the ride. The 
build.zig file for a project now looks like:

```zig
    const zigros_dep =
        b.dependency("zigros", .{
            .target = target,
            .optimize = optimize,
            .linkage = linkage,
            .@"system-python" = false,
        });
    // Ensure Lazy dependencies are all loaded
    if (b.graph.needed_lazy_dependencies.entries.len > 0) return;

    your_node.linkLibCpp();
    your_node.linkLibrary(zigros_dep.artifact("rclcpp"));
    your_node.linkLibrary(zigros_dep.artifact("rmw_cyclonedds_cpp")); // or other rmw of choice
    your_node.linkLibrary(zigros_dep.artifact("rcl_logging_spdlog")); // or other logger of choice

```

No more initializing a ZigRos object or calling helper functions. This is far more zig friendly.

There is still the small problem of interfaces. Each interface generates 6 code artifacts. 
Manually specifying all 6 of these is of course also tedious. To make matters worse, the actual 
types for rclcpp are generated as headers only, which don't play as nice with the zig build system. 
To streamline things, each language is now generated as a single library. This library is the 
combination of all rosidl generated outputs for each language. For example for the interface 
`std_msgs`, there's `std_msgs__rosidl_generator_c`, `std_msgs__rosidl_typesupport_c`, and 
`std_msgs__rosidl_typesupport_introspection_c` for C artifacts. These are all combined into a 
single `std_msgs_c` artifact, which also has all its dependencies exported. Similarly for C++, 
there's `std_msgs__rosidl_generator_cpp` (which is header only in this case), 
`std_msgs__rosidl_typesupport_cpp`, and `std_msgs__rosidl_typesupport_introspection_cpp` get 
combined into a single `std_msgs_cpp` library, reducing the number of libraries to think about, 
and tackling that pesky header only library at the same time. Note that if more type supports get 
added additional libraries may need to be included here. Given the ZigROS goal of static 
compilation, I don't see any practical downsides to combining the libraries in this way.

Build times seem roughly equivalent if not slightly faster with this approach (the slight speedup 
is likely related to the move to zig 0.15), and we can see the number of build steps are reduced
as we are now only building 2 libraries per language instead of 5 + a header only write file. 
Here's some stats from building the example node that's now in the example directory:

Old version:
```
Number of build steps: 267

time zig build
real	0m44.048s
user	8m33.358s
sys	1m36.002s
```

New version:
```
number of build steps 218

time zig build
real	0m38.053s
user	8m11.653s
sys	1m33.017s
```

One downside to this change is that it doesn't play well with shared libraries. There seems to 
be different handling of library dependencies if using shared libraries. It is still possible 
to build with everything shared, but doing so will require manually specifying some of the rcl
and rmw dependencies for some reason. This to me feels like a bug with zig. Given that the main 
goal of this project is static builds, I have opted to not troubleshoot this further. The build 
file in the example node in the examples directory demonstrates how to work around this.

