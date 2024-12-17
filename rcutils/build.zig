const std = @import("std");
const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const WriteFile = std.Build.Step.WriteFile;
const LazyPath = std.Build.LazyPath;
const CompileArgs = zigros.CompileArgs;
const PythonDep = zigros.PythonDep;

pub const Deps = struct {
    upstream: *Dependency,
};

pub const BuildDeps = struct {
    python: PythonDep,
    empy: ?LazyPath,
};

pub const Artifacts = struct {
    rcutils: *Compile,
    rcutils_py: *WriteFile,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps, build_deps: BuildDeps) Artifacts {
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.upstream;
    var lib = std.Build.Step.Compile.create(b, .{
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        },
        .name = "rcutils",
        .kind = .lib,
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        lib.link_function_sections = true;
        lib.link_data_sections = true;
    }

    var python_step: *std.Build.Step.Run = undefined;
    const python_command =
        \\import sys
        \\for arg in sys.argv:
        \\    if arg.startswith("-P"):
        \\        sys.path.append(arg.lstrip("-P"))
        \\import em
        \\output = sys.argv[-1]
        \\em.invoke(['-o', output, '-D', 'rcutils_module_path="./"', 'resource/logging_macros.h.em'])
    ;
    switch (build_deps.python) {
        .system => |python| {
            python_step = b.addSystemCommand(&.{ python, "-c", python_command });
        },
        .build => |python| {
            python_step = b.addRunArtifact(python);
            python_step.addArgs(&.{ "-I", "-c", python_command });
            python_step.addPrefixedDirectoryArg("-P", build_deps.empy.?);
        },
    }
    python_step.setCwd(upstream.path(""));

    const logging_output = python_step.addOutputFileArg("include/rcutils/logging_macros.h");
    lib.step.dependOn(&python_step.step);

    lib.linkLibC();
    lib.addIncludePath(upstream.path("include"));

    const time = switch (target.result.os.tag) {
        .windows => "src/time_win32.c",
        else => "src/time_unix.c",
    };
    lib.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/allocator.c",
            "src/array_list.c",
            "src/char_array.c",
            "src/cmdline_parser.c",
            "src/env.c",
            "src/error_handling.c",
            "src/filesystem.c",
            "src/find.c",
            "src/format_string.c",
            "src/hash_map.c",
            "src/logging.c",
            "src/qsort.c",
            "src/repl_str.c",
            "src/sha256.c",
            "src/shared_library.c",
            "src/snprintf.c",
            "src/split.c",
            "src/strcasecmp.c",
            "src/strdup.c",
            "src/strerror.c",
            "src/string_array.c",
            "src/string_map.c",
            "src/time.c",
            time,
            "src/uint8_array.c",
        },
        .flags = &.{"-fvisibility=hidden"},
    });

    // process.c assumes that program_invocation_name exists which is a gnu specific thing.
    // musl optionally supports this if the _GNU_SOURCE is specified,
    // however when enabling this across the board,
    // rcutils strerror.c tries to use the gnu version of strerror_r which musl doesn't seem to support.
    // To get around this, we define _GNU_SOURCE only for process.c
    lib.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/process.c",
        },
        .flags = &.{ "-D_GNU_SOURCE", "-fvisibility=hidden" },
    });

    // Add the parent directory to be sure that the file structuree is captured
    // This forces it to show up as "rcutils/logging_macro.h" instead of just "logging_macro.h"
    // Seems to work more consistently
    lib.addIncludePath(logging_output.dirname().dirname());
    lib.installHeader(logging_output, "rcutils/logging_macros.h");

    lib.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{},
    );
    b.installArtifact(lib);

    // Export python logging.py
    var python = b.addNamedWriteFiles("rcutils");
    _ = python.addCopyDirectory(
        upstream.path("rcutils"),
        "rcutils",
        .{ .exclude_extensions = &.{ "__pycache__", ".pyc" } },
    );
    b.installDirectory(.{
        .source_dir = python.getDirectory(),
        .install_dir = .{ .custom = "" },
        .install_subdir = "",
    });

    return .{ .rcutils = lib, .rcutils_py = python };
}
