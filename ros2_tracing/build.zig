const std = @import("std");

pub fn build(b: *std.Build) std.Build.LazyPath {
    const upstream = b.dependency("ros2_tracing", .{});

    // We're only going to export the include files with everything disabled for now
    // Saves us building the tracetool dependencies which aren't required for a running system

    // var lib = std.Build.Step.Compile.create(b, .{
    //     .root_module = .{
    //         .target = target,
    //         .optimize = optimize,
    //         .pic = if (linkage == .dynamic) true else null,
    //     },
    //     .name = "tracetools",
    //     .kind = .lib,
    //     .linkage = linkage,
    // });

    // lib.linkLibC();

    const config = b.addConfigHeader(
        .{
            .style = .{ .cmake = upstream.path("tracetools/include/tracetools/config.h.in") },
            .include_path = "tracetools/config.h",
        },
        .{ .TRACETOOLS_DISABLED = 1, .TRACETOOLS_TRACEPOINTS_EXCLUDED = 1 },
    );

    const artifact = b.addNamedWriteFiles("tracetools");
    _ = artifact.addCopyDirectory(
        upstream.path("tracetools/include/"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    _ = artifact.addCopyFile(config.getOutput(), "tracetools/config.h");

    b.installDirectory(.{
        .source_dir = artifact.getDirectory(),
        .install_dir = .{ .custom = "" },
        .install_subdir = "",
    });

    // lib.addConfigHeader(config);

    // lib.addIncludePath(upstream.path("tracetools/include/"));
    // lib.addCSourceFiles(.{
    //     .root = upstream.path("tracetools/"),
    //     .files = &.{
    //         "src/tracetools.c",
    //     },
    // });
    // lib.installHeadersDirectory(upstream.path("tracetools/include/"), "", .{});

    // b.installArtifact(lib);

    return artifact.getDirectory();
}
