const std = @import("std");
const zigros = @import("../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const WriteFile = std.Build.Step.WriteFile;
const LazyPath = std.Build.LazyPath;
const CompileArgs = zigros.CompileArgs;
const PythonDep = zigros.PythonDep;

// To access modules at build time in other packages, they must be included here in the build file
pub const RosidlGenerator = @import("src/RosidlGenerator.zig");

// Adds a named write file and install step using the given name and path.
// Optionally include a binary directory as well
fn exportPythonLibrary(
    b: *std.Build,
    name: []const u8,
    source_path: std.Build.LazyPath,
    bin_path: ?std.Build.LazyPath,
) *std.Build.Step.WriteFile {
    var write_file = b.addNamedWriteFiles(name);

    _ = write_file.addCopyDirectory(source_path, "", .{ .include_extensions = &.{ ".py", ".em", ".in", ".json", ".lark" } });

    if (bin_path) |bin| {
        _ = write_file.addCopyDirectory(bin, "bin", .{});
    }

    var install_step = b.addInstallDirectory(.{
        .source_dir = write_file.getDirectory(),
        .install_dir = .{ .custom = "python" },
        .install_subdir = name,
    });
    install_step.step.dependOn(&write_file.step);
    b.getInstallStep().dependOn(&install_step.step);

    return write_file;
}

pub const Deps = struct {
    rosidl_upstream: *Dependency,
    rosidl_typesupport_upstream: *Dependency,
    rosidl_dynamic_typesupport_upstream: *Dependency,
    rcutils: *Compile,
    rcpputils: *Compile,
};

pub const BuildDeps = struct {
    python: PythonDep,
    empy: ?LazyPath,
};

pub const Artifacts = struct {
    rosidl_typesupport_interface: LazyPath,
    rosidl_runtime_c: *Compile,
    rosidl_runtime_cpp: LazyPath,
    rosidl_typesupport_introspection_c: *Compile,
    rosidl_typesupport_introspection_cpp: *Compile,
    rosidl_typesupport_c: *Compile,
    rosidl_typesupport_cpp: *Compile,
    rosidl_dynamic_typesupport: *Compile,
    rosidl_adapter_py: LazyPath,
    rosidl_cli_py: LazyPath,
    rosidl_pycommon_py: LazyPath,
    rosidl_generator_c_py: LazyPath,
    rosidl_generator_cpp_py: LazyPath,
    rosidl_generator_type_description_py: LazyPath,
    rosidl_parser_py: LazyPath,
    rosidl_typesupport_introspection_c_py: LazyPath,
    rosidl_typesupport_introspection_cpp_py: LazyPath,
    rosidl_typesupport_c_py: LazyPath,
    rosidl_typesupport_cpp_py: LazyPath,
    type_description_generator: *Compile,
    adapter_generator: *Compile,
    code_generator: *Compile,
};

pub fn buildWithArgs(b: *std.Build, args: CompileArgs, deps: Deps, build_deps: BuildDeps) Artifacts {
    _ = build_deps;
    const target = args.target;
    const optimize = args.optimize;
    const linkage = args.linkage;

    const upstream = deps.rosidl_upstream;

    var rosidl_typesupport_interface = b.addNamedWriteFiles("rosidl_typesupport_interface");
    _ = rosidl_typesupport_interface.addCopyDirectory(upstream.path("rosidl_typesupport_interface/include"), "", .{});

    var rosidl_typesupport_interface_install = b.addInstallDirectory(.{
        .source_dir = rosidl_typesupport_interface.getDirectory(),
        .install_dir = .header,
        .install_subdir = "",
    });
    rosidl_typesupport_interface_install.step.dependOn(&rosidl_typesupport_interface.step);
    b.getInstallStep().dependOn(&rosidl_typesupport_interface_install.step);

    var rosidl_runtime_c = b.addLibrary(.{
        .name = "rosidl_runtime_c",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rosidl_runtime_c.link_function_sections = true;
        rosidl_runtime_c.link_data_sections = true;
    }

    rosidl_runtime_c.linkLibC();
    rosidl_runtime_c.linkLibrary(deps.rcutils);
    rosidl_runtime_c.addIncludePath(rosidl_typesupport_interface.getDirectory());
    rosidl_runtime_c.addIncludePath(upstream.path("rosidl_runtime_c/include"));

    rosidl_runtime_c.addCSourceFiles(.{
        .root = upstream.path("rosidl_runtime_c"),
        .files = &.{
            "src/message_type_support.c",
            "src/primitives_sequence_functions.c",
            "src/sequence_bound.c",
            "src/service_type_support.c",
            "src/string_functions.c",
            "src/type_hash.c",
            "src/u16string_functions.c",
            "src/type_description_utils.c",
            "src/type_description/field__description.c",
            "src/type_description/field__functions.c",
            "src/type_description/field_type__description.c",
            "src/type_description/field_type__functions.c",
            "src/type_description/individual_type_description__description.c",
            "src/type_description/individual_type_description__functions.c",
            "src/type_description/key_value__description.c",
            "src/type_description/key_value__functions.c",
            "src/type_description/type_description__description.c",
            "src/type_description/type_description__functions.c",
            "src/type_description/type_source__description.c",
            "src/type_description/type_source__functions.c",
        },
        .flags = &.{"-fvisibility=hidden"},
    });

    rosidl_runtime_c.installHeadersDirectory(
        upstream.path("rosidl_runtime_c/include"),
        "",
        .{},
    );
    b.installArtifact(rosidl_runtime_c);

    // rosidl_runtime_cpp is header only
    var rosidl_runtime_cpp = b.addNamedWriteFiles("rosidl_runtime_cpp");
    _ = rosidl_runtime_cpp.addCopyDirectory(upstream.path("rosidl_runtime_cpp/include"), "", .{});

    // Install step is optional really
    var rosidl_runtime_cpp_install = b.addInstallDirectory(.{
        .source_dir = rosidl_runtime_cpp.getDirectory(),
        .install_dir = .header,
        .install_subdir = "",
    });
    rosidl_runtime_cpp_install.step.dependOn(&rosidl_runtime_cpp.step);
    b.getInstallStep().dependOn(&rosidl_runtime_cpp_install.step);

    var rosidl_typesupport_introspection_c = b.addLibrary(.{
        .name = "rosidl_typesupport_introspection_c",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rosidl_typesupport_introspection_c.link_function_sections = true;
        rosidl_typesupport_introspection_c.link_data_sections = true;
    }

    rosidl_typesupport_introspection_c.linkLibC();

    rosidl_typesupport_introspection_c.linkLibrary(rosidl_runtime_c);
    rosidl_typesupport_introspection_c.addIncludePath(rosidl_typesupport_interface.getDirectory());
    rosidl_typesupport_introspection_c.addIncludePath(upstream.path("rosidl_typesupport_introspection_c/include"));

    rosidl_typesupport_introspection_c.step.dependOn(&rosidl_typesupport_interface.step);

    rosidl_typesupport_introspection_c.addCSourceFiles(.{
        .root = upstream.path("rosidl_typesupport_introspection_c"),
        .files = &.{
            "src/identifier.c",
        },
        .flags = &.{"-fvisibility=hidden"},
    });

    rosidl_typesupport_introspection_c.installHeadersDirectory(
        upstream.path("rosidl_typesupport_introspection_c/include"),
        "",
        .{},
    );
    b.installArtifact(rosidl_typesupport_introspection_c);

    var rosidl_typesupport_introspection_cpp = b.addLibrary(.{
        .name = "rosidl_typesupport_introspection_cpp",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rosidl_typesupport_introspection_cpp.link_function_sections = true;
        rosidl_typesupport_introspection_cpp.link_data_sections = true;
    }

    rosidl_typesupport_introspection_cpp.linkLibCpp();

    rosidl_typesupport_introspection_cpp.linkLibrary(rosidl_runtime_c);
    rosidl_typesupport_introspection_cpp.addIncludePath(rosidl_typesupport_interface.getDirectory());
    rosidl_typesupport_introspection_cpp.addIncludePath(rosidl_runtime_cpp.getDirectory());
    rosidl_typesupport_introspection_cpp.addIncludePath(upstream.path("rosidl_typesupport_introspection_cpp/include"));

    rosidl_typesupport_introspection_cpp.step.dependOn(&rosidl_runtime_cpp.step);

    rosidl_typesupport_introspection_cpp.addCSourceFiles(.{
        .root = upstream.path("rosidl_typesupport_introspection_cpp"),
        .files = &.{
            "src/identifier.cpp",
        },
        .flags = &.{
            "--std=c++17",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });

    rosidl_typesupport_introspection_cpp.installHeadersDirectory(
        upstream.path("rosidl_typesupport_introspection_cpp/include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );
    b.installArtifact(rosidl_typesupport_introspection_cpp);

    // Export python libraries as named write files
    const rosidl_adapter_py = exportPythonLibrary(b, "rosidl_adapter", upstream.path("rosidl_adapter"), null);
    const rosidl_cli_py = exportPythonLibrary(b, "rosidl_cli", upstream.path("rosidl_cli"), null);
    const rosidl_pycommon_py = exportPythonLibrary(b, "rosidl_pycommon", upstream.path("rosidl_pycommon"), null);

    const rosidl_generator_c_py = exportPythonLibrary(
        b,
        "rosidl_generator_c",
        upstream.path("rosidl_generator_c"),
        upstream.path("rosidl_generator_c/bin"),
    );
    const rosidl_generator_cpp_py = exportPythonLibrary(
        b,
        "rosidl_generator_cpp",
        upstream.path("rosidl_generator_cpp"),
        upstream.path("rosidl_generator_cpp/bin"),
    );
    const rosidl_generator_type_description_py = exportPythonLibrary(
        b,
        "rosidl_generator_type_description",
        upstream.path("rosidl_generator_type_description"),
        upstream.path("rosidl_generator_type_description/bin"),
    );
    const rosidl_parser_py = exportPythonLibrary(
        b,
        "rosidl_parser",
        upstream.path("rosidl_parser"),
        upstream.path("rosidl_parser/bin"),
    );
    const rosidl_typesupport_introspection_c_py = exportPythonLibrary(
        b,
        "rosidl_typesupport_introspection_c",
        upstream.path("rosidl_typesupport_introspection_c"),
        upstream.path("rosidl_typesupport_introspection_c/bin"),
    );
    const rosidl_typesupport_introspection_cpp_py = exportPythonLibrary(
        b,
        "rosidl_typesupport_introspection_cpp",
        upstream.path("rosidl_typesupport_introspection_cpp"),
        upstream.path("rosidl_typesupport_introspection_cpp/bin"),
    );

    // rosidl_typesupport
    const typesupport_upstream = deps.rosidl_typesupport_upstream;

    var rosidl_typesupport_c = b.addLibrary(.{
        .name = "rosidl_typesupport_c",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rosidl_typesupport_c.link_function_sections = true;
        rosidl_typesupport_c.link_data_sections = true;
    }

    rosidl_typesupport_c.linkLibCpp();
    rosidl_typesupport_c.linkLibrary(deps.rcutils);
    rosidl_typesupport_c.linkLibrary(deps.rcpputils);
    rosidl_typesupport_c.linkLibrary(rosidl_runtime_c);
    rosidl_typesupport_c.addIncludePath(rosidl_typesupport_interface.getDirectory());
    rosidl_typesupport_c.addIncludePath(typesupport_upstream.path("rosidl_typesupport_c/include"));

    rosidl_typesupport_c.addCSourceFiles(.{
        .root = typesupport_upstream.path("rosidl_typesupport_c"),
        .files = &.{
            "src/identifier.c",
        },
        .flags = &.{"-fvisibility=hidden"},
    });

    rosidl_typesupport_c.addCSourceFiles(.{
        .root = typesupport_upstream.path("rosidl_typesupport_c"),
        .files = &.{
            "src/message_type_support_dispatch.cpp",
            "src/service_type_support_dispatch.cpp",
        },
        .flags = &.{
            "--std=c++17",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });

    rosidl_typesupport_c.installHeadersDirectory(
        typesupport_upstream.path("rosidl_typesupport_c/include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    if (target.result.os.tag == .windows) {
        // Note windows is untested, this just tires to match the upstream CMake
        rosidl_typesupport_c.root_module.addCMacro("ROSIDL_TYPESUPPORT_C_BUILDING_DLL", "");
    }

    b.installArtifact(rosidl_typesupport_c);

    var rosidl_typesupport_cpp = b.addLibrary(.{
        .name = "rosidl_typesupport_cpp",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rosidl_typesupport_cpp.link_function_sections = true;
        rosidl_typesupport_cpp.link_data_sections = true;
    }

    rosidl_typesupport_cpp.linkLibCpp();
    rosidl_typesupport_cpp.linkLibrary(deps.rcutils);
    rosidl_typesupport_cpp.linkLibrary(deps.rcpputils);
    rosidl_typesupport_cpp.linkLibrary(rosidl_runtime_c);
    rosidl_typesupport_cpp.linkLibrary(rosidl_typesupport_c);
    rosidl_typesupport_cpp.addIncludePath(rosidl_typesupport_interface.getDirectory());
    rosidl_typesupport_cpp.addIncludePath(typesupport_upstream.path("rosidl_typesupport_cpp/include"));

    rosidl_typesupport_cpp.addCSourceFiles(.{
        .root = typesupport_upstream.path("rosidl_typesupport_cpp"),
        .files = &.{
            "src/identifier.cpp",
            "src/message_type_support_dispatch.cpp",
            "src/service_type_support_dispatch.cpp",
        },
        .flags = &.{
            "--std=c++17",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        },
    });

    rosidl_typesupport_cpp.installHeadersDirectory(
        typesupport_upstream.path("rosidl_typesupport_cpp/include"),
        "",
        .{ .include_extensions = &.{ ".h", ".hpp" } },
    );

    if (target.result.os.tag == .windows) {
        // Note windows is untested, this just tires to match the upstream CMake
        rosidl_typesupport_cpp.root_module.addCMacro("ROSIDL_TYPESUPPORT_CPP_BUILDING_DLL", "");
    }

    b.installArtifact(rosidl_typesupport_cpp);

    const rosidl_typesupport_c_py = exportPythonLibrary(
        b,
        "rosidl_typesupport_c",
        typesupport_upstream.path("rosidl_typesupport_c"),
        typesupport_upstream.path("rosidl_typesupport_c/bin"),
    );
    const rosidl_typesupport_cpp_py = exportPythonLibrary(
        b,
        "rosidl_typesupport_cpp",
        typesupport_upstream.path("rosidl_typesupport_cpp"),
        typesupport_upstream.path("rosidl_typesupport_cpp/bin"),
    );

    // rosidl_dynamic_typesupport
    const dynamic_typesupport_upstream = deps.rosidl_dynamic_typesupport_upstream;

    var rosidl_dynamic_typesupport = b.addLibrary(.{
        .name = "rosidl_dynamic_typesupport",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .pic = if (linkage == .dynamic) true else null,
        }),
        .linkage = linkage,
    });

    if (optimize == .ReleaseSmall and linkage == .static) {
        rosidl_dynamic_typesupport.link_function_sections = true;
        rosidl_dynamic_typesupport.link_data_sections = true;
    }

    rosidl_dynamic_typesupport.linkLibC();
    rosidl_dynamic_typesupport.linkLibrary(deps.rcutils);
    rosidl_dynamic_typesupport.linkLibrary(rosidl_runtime_c);
    rosidl_dynamic_typesupport.addIncludePath(rosidl_typesupport_interface.getDirectory());
    rosidl_dynamic_typesupport.addIncludePath(dynamic_typesupport_upstream.path("include"));

    rosidl_dynamic_typesupport.addCSourceFiles(.{
        .root = dynamic_typesupport_upstream.path(""),
        .files = &.{
            "src/api/serialization_support.c",
            "src/api/dynamic_data.c",
            "src/api/dynamic_type.c",
            "src/dynamic_message_type_support_struct.c",
            "src/identifier.c",
        },
        .flags = &.{"-fvisibility=hidden"},
    });

    rosidl_dynamic_typesupport.installHeadersDirectory(
        dynamic_typesupport_upstream.path("include"),
        "",
        .{},
    );

    if (target.result.os.tag == .windows) {
        // Note windows is untested, this just tires to match the upstream CMake
        rosidl_dynamic_typesupport.root_module.addCMacro("ROSIDL_TYPESUPPORT_C_BUILDING_DLL", "");
    }

    b.installArtifact(rosidl_dynamic_typesupport);

    // Zig specific stuff to replace all the CMake magic involved in interface generation

    const type_description_generator = b.addExecutable(.{
        .name = "type_description_generator",
        .target = b.graph.host, // This is only used in run artifacts, don't cross compile
        .optimize = optimize,
        .root_source_file = b.path("rosidl/src/type_description_generator.zig"),
    });
    b.installArtifact(type_description_generator);

    const adapter_generator = b.addExecutable(.{
        .name = "adapter_generator",
        .target = b.graph.host, // This is only used in run artifacts, don't cross compile
        .optimize = optimize,
        .root_source_file = b.path("rosidl/src/adapter_generator.zig"),
    });
    b.installArtifact(adapter_generator);

    const code_generator = b.addExecutable(.{
        .name = "code_generator",
        .target = b.graph.host, // This is only used in run artifacts, don't cross compile
        .optimize = optimize,
        .root_source_file = b.path("rosidl/src/code_generator.zig"),
    });
    b.installArtifact(code_generator);

    const rosidl_generator = b.addModule("RosidlGenerator", .{ .root_source_file = b.path("src/RosidlGenerator.zig") });
    _ = rosidl_generator;

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("rosidl/src/RosidlGeneratorTemplate.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    return .{
        .rosidl_typesupport_interface = rosidl_typesupport_interface.getDirectory(),
        .rosidl_runtime_c = rosidl_runtime_c,
        .rosidl_runtime_cpp = rosidl_runtime_cpp.getDirectory(),
        .rosidl_typesupport_introspection_c = rosidl_typesupport_introspection_c,
        .rosidl_typesupport_introspection_cpp = rosidl_typesupport_introspection_cpp,
        .rosidl_typesupport_c = rosidl_typesupport_c,
        .rosidl_typesupport_cpp = rosidl_typesupport_cpp,
        .rosidl_dynamic_typesupport = rosidl_dynamic_typesupport,
        .rosidl_adapter_py = rosidl_adapter_py.getDirectory(),
        .rosidl_cli_py = rosidl_cli_py.getDirectory(),
        .rosidl_pycommon_py = rosidl_pycommon_py.getDirectory(),
        .rosidl_generator_c_py = rosidl_generator_c_py.getDirectory(),
        .rosidl_generator_cpp_py = rosidl_generator_cpp_py.getDirectory(),
        .rosidl_generator_type_description_py = rosidl_generator_type_description_py.getDirectory(),
        .rosidl_parser_py = rosidl_parser_py.getDirectory(),
        .rosidl_typesupport_introspection_c_py = rosidl_typesupport_introspection_c_py.getDirectory(),
        .rosidl_typesupport_introspection_cpp_py = rosidl_typesupport_introspection_cpp_py.getDirectory(),
        .rosidl_typesupport_c_py = rosidl_typesupport_c_py.getDirectory(),
        .rosidl_typesupport_cpp_py = rosidl_typesupport_cpp_py.getDirectory(),
        .type_description_generator = type_description_generator,
        .adapter_generator = adapter_generator,
        .code_generator = code_generator,
    };
}
