const std = @import("std");

const zigros = @import("../zigros/zigros.zig");

const Compile = std.Build.Step.Compile;
const CompileArgs = zigros.CompileArgs;

pub fn buildWithArgs(b: *std.Build, args: CompileArgs) *Compile {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = b.dependency("ament_index", .{});

    var ament_index_cpp = std.Build.Step.Compile.create(b, .{
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        },
        .name = "ament_index_cpp",
        .kind = .lib,
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        ament_index_cpp.link_function_sections = true;
        ament_index_cpp.link_data_sections = true;
    }

    ament_index_cpp.linkLibCpp();

    ament_index_cpp.addIncludePath(upstream.path("ament_index_cpp/include"));
    ament_index_cpp.installHeadersDirectory(
        upstream.path("ament_index_cpp/include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    ament_index_cpp.addCSourceFiles(.{
        .root = upstream.path("ament_index_cpp"),
        .files = &.{
            "src/get_package_prefix.cpp",
            "src/get_package_share_directory.cpp",
            "src/get_packages_with_prefixes.cpp",
            "src/get_resource.cpp",
            "src/get_resources.cpp",
            "src/get_search_paths.cpp",
            "src/has_resource.cpp",
        },
        .flags = &.{
            "--std=c++17",
            // "-fvisibility=hidden", // TODO this breaks this package
            // "-fvisibility-inlines-hidden",
        },
    });
    b.installArtifact(ament_index_cpp);

    return ament_index_cpp;
}
