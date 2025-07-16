const std = @import("std");
const zigros = @import("../../zigros/zigros.zig");

const Dependency = std.Build.Dependency;
const Module = std.Build.Module;
const Run = std.Build.Step.Run;
const Compile = std.Build.Step.Compile;
const WriteFile = std.Build.Step.WriteFile;
const LazyPath = std.Build.LazyPath;
const CompileArgs = zigros.CompileArgs;
const PythonDep = zigros.PythonDep;

const RosidlGenerator = @This();
const RosidlTypeDescription = @import("RosidlTypeDescription.zig");
const CodeGenerator = @import("RosidlGeneratorTemplate.zig").CodeGenerator;
const RosidlAdapter = @import("RosidlAdapter.zig");

const RosidlGeneratorC = CodeGenerator(
    .c,
    .h,
    &.{
        "{s}/{s}/detail/{s}__description.c",
        "{s}/{s}/detail/{s}__functions.c",
        "{s}/{s}/detail/{s}__type_support.c",
    },
);

const RosidlGeneratorCpp = CodeGenerator(
    .header_only,
    .hpp,
    &.{},
);

const RosidlTypesupportC = CodeGenerator(
    .cpp,
    null,
    &.{"{s}/{s}/{s}__type_support.cpp"},
);

const RosidlTypesupportCpp = CodeGenerator(
    .cpp,
    null,
    &.{"{s}/{s}/{s}__type_support.cpp"},
);

const RosidlTypesupportIntrospectionC = CodeGenerator(
    .c,
    .h,
    &.{"{s}/{s}/detail/{s}__type_support.c"},
);

const RosidlTypesupportIntrospectionCpp = CodeGenerator(
    .cpp,
    null,
    &.{"{s}/{s}/detail/{s}__type_support.cpp"},
);

pub const Interface = struct {
    share: LazyPath,
    interface_c: *Compile,
    interface_cpp: LazyPath,
    typesupport_c: *Compile,
    typesupport_cpp: *Compile,
    typesupport_introspection_c: *Compile,
    typesupport_introspection_cpp: *Compile,
    c: *Compile, // Brings in all c libraries into one library
    cpp: *Compile, // Brings in all cpp libraries into one library, particularly useful since zig doesn't seem to support header only "librarys"

    pub fn link(self: Interface, target: *Module) void {
        self.linkC(target);
        self.linkCpp(target);
    }

    // Link against only the c libraries. In theory useful for rcl only builds
    // though all rmw implementations require c++ so in practice not that useful
    pub fn linkC(self: Interface, target: *Module) void {
        target.linkLibrary(self.interface_c);
        target.linkLibrary(self.typesupport_c);
        target.linkLibrary(self.typesupport_introspection_c);
    }

    // Note this function should only be used if linkC has been called previously on the same module,
    // otherwise the standard link function should be used
    // use the normal public link function for general c++ lingking
    pub fn linkCpp(self: Interface, target: *Module) void {
        target.addIncludePath(self.interface_cpp);
        target.linkLibrary(self.typesupport_cpp);
        target.linkLibrary(self.typesupport_introspection_cpp);
    }
};

pub const BuildDeps = struct {
    python: PythonDep,
    empy: ?LazyPath, // Required when non system python is used
    lark: ?LazyPath, // Required when non system python is used
    rosidl_cli: LazyPath,
    rosidl_adapter: LazyPath,
    rosidl_parser: LazyPath,
    rosidl_pycommon: LazyPath,
    rosidl_generator_type_description: LazyPath,
    rosidl_generator_c: LazyPath,
    rosidl_generator_cpp: LazyPath,
    rosidl_typesupport_c: LazyPath,
    rosidl_typesupport_cpp: LazyPath,
    rosidl_typesupport_introspection_c: LazyPath,
    rosidl_typesupport_introspection_cpp: LazyPath,
    type_description_generator: *Compile,
    adapter_generator: *Compile,
    code_generator: *Compile,
};

pub const Deps = struct {
    rosidl_runtime_c: *Compile,
    rosidl_runtime_cpp: LazyPath,
    rosidl_typesupport_interface: LazyPath,
    rosidl_typesupport_c: *Compile,
    rosidl_typesupport_cpp: *Compile,
    rosidl_typesupport_introspection_c: *Compile,
    rosidl_typesupport_introspection_cpp: *Compile,
    rcutils: *Compile,
};

owner: *std.Build,
package_name: []const u8,
deps: Deps,
build_deps: BuildDeps,
artifacts: Interface,
share_dir: *WriteFile,
adapter: *RosidlAdapter,
type_description: *RosidlTypeDescription,
generator_c: *RosidlGeneratorC,
generator_cpp: *RosidlGeneratorCpp,
typesupport_c: *RosidlTypesupportC,
typesupport_cpp: *RosidlTypesupportCpp,
typesupport_introspection_c: *RosidlTypesupportIntrospectionC,
typesupport_introspection_cpp: *RosidlTypesupportIntrospectionCpp,
dependency: Dependency,

pub fn create(
    b: *std.Build,
    package_name: []const u8,
    deps: Deps,
    build_deps: BuildDeps,
    compile_args: CompileArgs,
) *RosidlGenerator {
    const to_return = b.allocator.create(RosidlGenerator) catch @panic("OOM");
    to_return.* = .{
        .owner = b,
        .package_name = b.dupe(package_name),
        .deps = deps,
        .build_deps = build_deps,
        .artifacts = undefined,
        .share_dir = b.addNamedWriteFiles(package_name),
        .adapter = undefined,
        .type_description = undefined,
        .generator_c = undefined,
        .generator_cpp = undefined,
        .typesupport_c = undefined,
        .typesupport_cpp = undefined,
        .typesupport_introspection_c = undefined,
        .typesupport_introspection_cpp = undefined,
        .dependency = .{ .builder = b },
    };

    to_return.adapter = RosidlAdapter.create(b, build_deps, package_name);
    _ = to_return.share_dir.addCopyDirectory(
        to_return.adapter.output,
        "",
        .{ .include_extensions = &.{".idl"} },
    );

    to_return.type_description = RosidlTypeDescription.create(b, build_deps, package_name);
    _ = to_return.share_dir.addCopyDirectory(
        to_return.type_description.output,
        "",
        .{ .include_extensions = &.{".json"} },
    );

    to_return.generator_c = RosidlGeneratorC.create(
        b,
        package_name,
        compile_args,
        "rosidl_generator_c",
        build_deps.rosidl_generator_c,
        deps,
        build_deps,
        &.{.{ .lib = deps.rosidl_runtime_c }},
        null,
    );
    to_return.generator_cpp = RosidlGeneratorCpp.create(
        b,
        package_name,
        compile_args,
        "rosidl_generator_cpp",
        build_deps.rosidl_generator_cpp,
        deps,
        build_deps,
        null,
        &.{build_deps.rosidl_generator_c},
    );

    to_return.typesupport_introspection_c = RosidlTypesupportIntrospectionC.create(
        b,
        package_name,
        compile_args,
        "rosidl_typesupport_introspection_c",
        build_deps.rosidl_typesupport_introspection_c,
        deps,
        build_deps,
        &.{
            .{ .lib = deps.rosidl_runtime_c },
            .{ .lib = deps.rosidl_typesupport_introspection_c },
            .{ .lib = to_return.generator_c.artifact },
        },
        &.{build_deps.rosidl_generator_c},
    );

    to_return.typesupport_introspection_cpp = RosidlTypesupportIntrospectionCpp.create(
        b,
        package_name,
        compile_args,
        "rosidl_typesupport_introspection_cpp",
        build_deps.rosidl_typesupport_introspection_cpp,
        deps,
        build_deps,
        &.{
            .{ .lib = deps.rosidl_runtime_c },
            .{ .header_only = deps.rosidl_runtime_cpp },
            .{ .lib = deps.rosidl_typesupport_introspection_cpp },
            .{ .lib = deps.rosidl_typesupport_cpp },
            .{ .lib = to_return.generator_c.artifact },
            .{ .header_only = to_return.generator_cpp.artifact.getDirectory() },
            .{ .lib = deps.rosidl_typesupport_introspection_c },
        },
        &.{
            build_deps.rosidl_generator_cpp,
            build_deps.rosidl_generator_c,
        },
    );

    to_return.typesupport_c = RosidlTypesupportC.create(
        b,
        package_name,
        compile_args,
        "rosidl_typesupport_c",
        build_deps.rosidl_typesupport_c,
        deps,
        build_deps,
        &.{
            .{ .lib = deps.rosidl_runtime_c },
            .{ .lib = to_return.generator_c.artifact },
            .{ .lib = deps.rosidl_typesupport_c },
            // Note that when building single type support, you must link the type support package
            // directly against that single type support.
            .{ .lib = to_return.typesupport_introspection_c.artifact },
        },
        &.{build_deps.rosidl_generator_c},
    );

    // The type supports normally come from the ament index. Search for
    // `ament_index_register_resource("rosidl_typesupport_c`) on github in ros to get a list
    // For now we only support the standard dynamic typesupport_introspection versions
    to_return.typesupport_c.generator.addArg(
        "-A--typesupports rosidl_typesupport_introspection_c",
    );

    to_return.typesupport_cpp = RosidlTypesupportCpp.create(
        b,
        package_name,
        compile_args,
        "rosidl_typesupport_cpp",
        build_deps.rosidl_typesupport_cpp,
        deps,
        build_deps,
        &.{
            .{ .lib = deps.rosidl_runtime_c },
            .{ .lib = to_return.generator_c.artifact },
            .{ .header_only = to_return.generator_cpp.artifact.getDirectory() },
            .{ .header_only = deps.rosidl_runtime_cpp },
            .{ .lib = deps.rosidl_typesupport_cpp },
            // Note that when building single type support, you must link the type support package
            // directly against that single type support.
            .{ .lib = to_return.typesupport_introspection_cpp.artifact },
            .{ .lib = deps.rosidl_typesupport_introspection_cpp },
        },
        &.{build_deps.rosidl_generator_c},
    );

    // The type supports normally come from the ament index. Search for
    // `ament_index_register_resource("rosidl_typesupport_c`) on github in ros to get a list
    // For now we only support the standard dynamic typesupport_introspection versions
    to_return.typesupport_cpp.generator.addArg(
        "-A--typesupports rosidl_typesupport_introspection_cpp",
    );

    var name_tmp: []u8 = undefined;
    // used for the single library variants which at least for now is always package_name_c or package_name_cpp.
    name_tmp = std.mem.concat(b.allocator, u8, &.{ package_name, "_cpp" }) catch @panic("OOM");
    defer b.allocator.free(name_tmp);

    to_return.artifacts = .{
        .share = to_return.share_dir.getDirectory(),
        .interface_c = to_return.generator_c.artifact,
        .interface_cpp = to_return.generator_cpp.artifact.getDirectory(),
        .typesupport_c = to_return.typesupport_c.artifact,
        .typesupport_cpp = to_return.typesupport_cpp.artifact,
        .typesupport_introspection_c = to_return.typesupport_introspection_c.artifact,
        .typesupport_introspection_cpp = to_return.typesupport_introspection_cpp.artifact,
        .c = b.addLibrary(.{
            .name = name_tmp[0 .. package_name.len + "_c".len], // extract just the _c suffix substring
            .root_module = b.createModule(.{
                .target = compile_args.target,
                .optimize = compile_args.optimize,
                .pic = if (compile_args.linkage == .dynamic) true else null,
            }),
            .linkage = compile_args.linkage,
        }),
        .cpp = b.addLibrary(.{
            .name = name_tmp,
            .root_module = b.createModule(.{
                .target = compile_args.target,
                .optimize = compile_args.optimize,
                .pic = if (compile_args.linkage == .dynamic) true else null,
            }),
            .linkage = compile_args.linkage,
        }),
    };

    to_return.artifacts.c.linkLibrary(deps.rcutils);
    to_return.artifacts.c.addIncludePath(deps.rosidl_typesupport_interface);
    to_return.artifacts.c.linkLibrary(deps.rosidl_runtime_c);
    to_return.artifacts.c.linkLibrary(deps.rosidl_typesupport_c);
    to_return.artifacts.c.linkLibrary(deps.rosidl_typesupport_introspection_c);
    to_return.artifacts.c.installLibraryHeaders(deps.rosidl_typesupport_introspection_c);
    to_return.artifacts.c.linkLibC();

    // Include all generated headers and flag for install
    to_return.artifacts.c.addIncludePath(to_return.generator_c.generator_output);
    to_return.artifacts.c.installHeadersDirectory(to_return.generator_c.generator_output, "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    to_return.artifacts.c.addConfigHeader(to_return.generator_c.visibility_control_header);
    to_return.artifacts.c.installConfigHeader(to_return.generator_c.visibility_control_header);
    to_return.artifacts.c.addIncludePath(to_return.typesupport_c.generator_output);
    to_return.artifacts.c.installHeadersDirectory(to_return.typesupport_c.generator_output, "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    to_return.artifacts.c.addIncludePath(to_return.typesupport_introspection_c.generator_output);
    to_return.artifacts.c.installHeadersDirectory(to_return.typesupport_introspection_c.generator_output, "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    to_return.artifacts.c.addConfigHeader(to_return.typesupport_introspection_c.visibility_control_header);
    to_return.artifacts.c.installConfigHeader(to_return.typesupport_introspection_c.visibility_control_header);

    // Since the cpp interface generator is header only, we can add the lazy paths up front.
    to_return.artifacts.cpp.addIncludePath(to_return.artifacts.interface_cpp);
    to_return.artifacts.cpp.installHeadersDirectory(to_return.artifacts.interface_cpp, "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    to_return.artifacts.c.addIncludePath(to_return.typesupport_cpp.generator_output);
    to_return.artifacts.c.installHeadersDirectory(to_return.typesupport_cpp.generator_output, "", .{ .include_extensions = &.{ ".h", ".hpp" } });
    to_return.artifacts.c.addIncludePath(to_return.typesupport_introspection_cpp.generator_output);
    to_return.artifacts.c.installHeadersDirectory(to_return.typesupport_introspection_cpp.generator_output, "", .{ .include_extensions = &.{ ".h", ".hpp" } });

    to_return.artifacts.cpp.linkLibrary(deps.rcutils);
    to_return.artifacts.cpp.addIncludePath(deps.rosidl_typesupport_interface);
    to_return.artifacts.cpp.linkLibrary(deps.rosidl_runtime_c);
    to_return.artifacts.cpp.addIncludePath(deps.rosidl_runtime_cpp);
    to_return.artifacts.cpp.linkLibrary(deps.rosidl_typesupport_cpp);
    to_return.artifacts.cpp.linkLibrary(deps.rosidl_typesupport_introspection_cpp);

    to_return.artifacts.cpp.linkLibrary(to_return.artifacts.c);
    to_return.artifacts.cpp.installLibraryHeaders(to_return.artifacts.c);

    if (compile_args.optimize == .ReleaseSmall and compile_args.linkage == .static) {
        to_return.artifacts.c.link_function_sections = true;
        to_return.artifacts.c.link_data_sections = true;
        to_return.artifacts.cpp.link_function_sections = true;
        to_return.artifacts.cpp.link_data_sections = true;
    }

    return to_return;
}

pub fn addInterfaces(
    self: *RosidlGenerator,
    base_path: std.Build.LazyPath,
    files: []const []const u8,
) void {
    // TODO add actions
    for (files) |file| {
        self.adapter.addInterface(base_path, file);

        const idl = std.fmt.allocPrint(
            self.owner.allocator,
            "{s}idl",
            .{file[0 .. file.len - 3]},
        ) catch @panic("OOM");

        self.type_description.addIdlTuple(idl, self.adapter.output);

        const type_description = std.fmt.allocPrint(
            self.owner.allocator,
            "{s}json",
            .{file[0 .. file.len - 3]},
        ) catch @panic("OOM");

        self.generator_c.addInterface(base_path, file);
        // TODO this should tack on the same file added to generator c
        self.artifacts.c.root_module.link_objects.append(
            self.artifacts.c.root_module.owner.allocator,
            self.generator_c.artifact.root_module.link_objects.getLast(),
        ) catch @panic("OOM");
        self.generator_c.addIdlTuple(idl, self.adapter.output);
        self.generator_c.addTypeDescription(
            idl,
            self.type_description.output.path(self.owner, type_description),
        );

        self.generator_cpp.addInterface(base_path, file);
        self.generator_cpp.addIdlTuple(idl, self.adapter.output);
        self.generator_cpp.addTypeDescription(
            idl,
            self.type_description.output.path(self.owner, type_description),
        );

        self.typesupport_introspection_c.addInterface(base_path, file);
        // TODO this should tack on the same file added to generator c
        self.artifacts.c.root_module.link_objects.append(
            self.artifacts.c.root_module.owner.allocator,
            self.typesupport_introspection_c.artifact.root_module.link_objects.getLast(),
        ) catch @panic("OOM");
        self.typesupport_introspection_c.addIdlTuple(idl, self.adapter.output);
        self.typesupport_introspection_c.addTypeDescription(
            idl,
            self.type_description.output.path(self.owner, type_description),
        );

        self.typesupport_introspection_cpp.addInterface(base_path, file);
        // TODO this should tack on the same file added to generator c
        self.artifacts.cpp.root_module.link_objects.append(
            self.artifacts.cpp.root_module.owner.allocator,
            self.typesupport_introspection_cpp.artifact.root_module.link_objects.getLast(),
        ) catch @panic("OOM");
        self.typesupport_introspection_cpp.addIdlTuple(idl, self.adapter.output);
        self.typesupport_introspection_cpp.addTypeDescription(
            idl,
            self.type_description.output.path(self.owner, type_description),
        );

        self.typesupport_c.addInterface(base_path, file);
        // TODO this should tack on the same file added to generator c
        self.artifacts.c.root_module.link_objects.append(
            self.artifacts.c.root_module.owner.allocator,
            self.typesupport_c.artifact.root_module.link_objects.getLast(),
        ) catch @panic("OOM");
        self.typesupport_c.addIdlTuple(idl, self.adapter.output);
        self.typesupport_c.addTypeDescription(
            idl,
            self.type_description.output.path(self.owner, type_description),
        );

        self.typesupport_cpp.addInterface(base_path, file);
        // TODO this should tack on the same file added to generator c
        self.artifacts.cpp.root_module.link_objects.append(
            self.artifacts.cpp.root_module.owner.allocator,
            self.typesupport_cpp.artifact.root_module.link_objects.getLast(),
        ) catch @panic("OOM");
        self.typesupport_cpp.addIdlTuple(idl, self.adapter.output);
        self.typesupport_cpp.addTypeDescription(
            idl,
            self.type_description.output.path(self.owner, type_description),
        );

        const path = base_path.path(self.owner, file);
        _ = self.share_dir.addCopyFile(path, file);
    }
}

pub fn addDependency(self: *RosidlGenerator, name: []const u8, dependency: Interface) void {
    self.type_description.addIncludePath(name, dependency.share);

    dependency.linkC(self.generator_c.artifact.root_module);
    dependency.linkC(self.typesupport_c.artifact.root_module);
    dependency.linkC(self.typesupport_introspection_c.artifact.root_module);
    // The c artifact is meant to be all encompasing and bring its own dependencies
    self.artifacts.c.linkLibrary(dependency.c);
    self.artifacts.c.installLibraryHeaders(dependency.c);

    dependency.link(self.typesupport_cpp.artifact.root_module);
    dependency.link(self.typesupport_introspection_cpp.artifact.root_module);
    // The cpp artifact is meant to be all encompasing and bring its own dependencies
    self.artifacts.cpp.linkLibrary(dependency.cpp);
    self.artifacts.cpp.installLibraryHeaders(dependency.cpp);
}

const PythonArguments = union(enum) {
    string: []const u8,
    lazy_path: std.Build.LazyPath,
};

pub fn installArtifacts(self: *RosidlGenerator) void {
    var b = self.owner;
    b.installDirectory(.{
        .source_dir = self.share_dir
            .getDirectory(),
        .install_dir = .{ .custom = self.package_name },
        .install_subdir = "",
    });

    b.installArtifact(self.generator_c.artifact);

    b.installDirectory(.{
        .source_dir = self.generator_cpp.artifact.getDirectory(),
        .install_dir = .header,
        .install_subdir = "",
    });

    b.installArtifact(self.typesupport_c.artifact);
    b.installArtifact(self.typesupport_cpp.artifact);
    b.installArtifact(self.typesupport_introspection_c.artifact);
    b.installArtifact(self.typesupport_introspection_cpp.artifact);
    b.installArtifact(self.artifacts.c);
    b.installArtifact(self.artifacts.cpp);
}
