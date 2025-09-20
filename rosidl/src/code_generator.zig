const std = @import("std");
const builtin = @import("builtin");

// The various typesupport generators, like much of rosidl uses an arguments file instead of direct
// command line arguments.  This program wraps that by taking all arguments as command line
// arguments and writing to an arguments file automatically. This both writes the args file and
// calls the provided generator in one program. All arguments are prefixed to play nice with
// Zigs "addPrefixed" class of functions on the run step.
//
//  -X the specific generator to run
//  -P additional python paths to include
//  -A additional arguments that get passed on tot he generator call
//  -D must be an IDL u tuple in the form of {idl file}:{path to file}
//  -Y must be a type description tuple in the form of {type descroption file}:{path to file}
//  -I path to interface file
//  -N the name of the package
//  -G the name of the generator
//  -O the output directory to put generated files
//  -T the template directory for the generator
//  -B the python executable to run with
//  -l if passed, include logging when in debug build
var debug_allocator = std.heap.DebugAllocator(.{}).init;
pub fn main() !u8 {
    const gpa = if (builtin.mode == .Debug) debug_allocator.allocator() else std.heap.smp_allocator;
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer if (builtin.mode == .Debug) {
        arena.deinit();
    };
    const a = arena.allocator();

    const args = try std.process.argsAlloc(a);

    var package_name: ?[]const u8 = null;
    var generator_name: ?[]const u8 = null;
    var output_dir: ?[]const u8 = null;
    var template_dir: ?[]const u8 = null;
    var program: ?[]const u8 = null;
    var idl_tuples: std.ArrayList([]const u8) = .empty;
    var type_description_tuples: std.ArrayList([]const u8) = .empty;
    var interface_files: std.ArrayList([]const u8) = .empty;
    var python_path_args: std.ArrayList([]const u8) = .empty;
    var python: ?[]const u8 = null;
    var additional_args: std.ArrayList([]const u8) = .empty;

    var logging = false;

    for (args[1..]) |arg| if (arg.len < 2) {
        std.log.err("invalid argument, length must be greater than 2", .{});
        return error.InvalidArgument;
    } else if (std.mem.eql(u8, "-X", arg[0..2])) {
        program = arg[2..];
    } else if (std.mem.eql(u8, "-P", arg[0..2])) {
        try python_path_args.append(a, arg[2..]);
    } else if (std.mem.eql(u8, "-A", arg[0..2])) {
        try additional_args.append(a, arg[2..]);
    } else if (std.mem.eql(u8, "-D", arg[0..2])) {
        var it = std.mem.tokenizeAny(u8, arg[2..], ":");
        const idl = it.next() orelse return error.IdlTupleEmpty;
        const path = it.next() orelse return error.IdlTupleMissingDelimiter;
        try idl_tuples.append(a, try std.fmt.allocPrint(arena.allocator(), "{s}:{s}", .{ path, idl }));
    } else if (std.mem.eql(u8, "-Y", arg[0..2])) {
        try type_description_tuples.append(a, arg[2..]);
    } else if (std.mem.eql(u8, "-I", arg[0..2])) {
        try interface_files.append(a, arg[2..]);
    } else if (std.mem.eql(u8, "-N", arg[0..2])) {
        if (package_name) |_| return error.MultiplePackageNamesProvided;
        package_name = arg[2..];
    } else if (std.mem.eql(u8, "-G", arg[0..2])) {
        if (generator_name) |_| return error.MultipleGeneratorNamesProvided;
        generator_name = arg[2..];
    } else if (std.mem.eql(u8, "-O", arg[0..2])) {
        if (output_dir) |_| return error.MultipleOutputDirsProvided;
        output_dir = arg[2..];
    } else if (std.mem.eql(u8, "-B", arg[0..2])) {
        if (python) |_| return error.MultiplePythonExecutablesProvided;
        python = arg[2..];
    } else if (std.mem.eql(u8, "-T", arg[0..2])) {
        if (template_dir) |_| return error.MultipleTemplateDirsProvided;
        template_dir = arg[2..];
    } else if (std.mem.eql(u8, "-l", arg[0..2])) {
        logging = true;
        if (builtin.mode != .Debug) {
            std.log.info("Logging is set to true but build mode is not debug. Switch to debug to see logs.", .{});
        }
    };

    const ros_interface_dependencies: []const []const u8 = &.{}; // no generator actually uses these it seems, leaving blank for now
    const target_dependencies: []const []const u8 = &.{}; // no generator actually uses these it seems. the upstream IDL files seem to end up here again? also there's boiler plate depenedncies that we don't seem to need?

    const args_file_path = try std.fmt.allocPrint(a, "{s}/{s}__arguments.json", .{
        output_dir orelse return error.OutputDirNotProvided,
        generator_name orelse return error.GeneratorNameNotProvided,
    });
    var output_file = try std.fs.createFileAbsolute(args_file_path, .{});
    var output_file_buf: [4096]u8 = undefined;
    defer output_file.close();
    var json_writer = output_file.writer(&output_file_buf);

    var stringify = std.json.Stringify{ .writer = &json_writer.interface };
    try stringify.write(.{
        .package_name = package_name orelse return error.PackageNameNotProvided,
        .output_dir = try std.fmt.allocPrint(a, "{s}/{s}", .{
            output_dir orelse return error.OutputDirNotProvided,
            package_name orelse return error.PackageNameNotProvided, // Need to include package name for header paths to work
        }),
        .template_dir = template_dir orelse return error.TemplateDirNotProvided,
        .idl_tuples = idl_tuples.items,
        .ros_interface_files = interface_files.items,
        .ros_interface_dependencies = ros_interface_dependencies,
        .target_dependencies = target_dependencies,
        .type_description_tuples = type_description_tuples.items,
    });
    try json_writer.interface.flush();

    var argv = try std.ArrayList([]const u8).initCapacity(a, 10);
    argv.appendSliceAssumeCapacity(&.{
        python orelse return error.PythonExeNotProvided,
        program orelse return error.NoProgram,
        "--generator-arguments-file",
        args_file_path,
    });

    for (additional_args.items) |arg| {
        // split any space separated args
        var spliterator = std.mem.splitScalar(u8, arg, ' ');
        while (spliterator.next()) |next_arg| {
            try argv.append(a, next_arg);
        }
    }

    var child = std.process.Child.init(argv.items, arena.allocator());

    var pythonpath_string: std.ArrayList(u8) = .empty;
    if (python_path_args.items.len > 0) {
        for (python_path_args.items) |python_path| {
            try pythonpath_string.print(a, "{s}:", .{python_path});
        }
        // remove trailing :
        pythonpath_string.shrinkRetainingCapacity(pythonpath_string.items.len - 1);
    }
    var env = std.process.EnvMap.init(a);
    try env.put("PYTHONPATH", pythonpath_string.items);
    child.env_map = &env;

    if (builtin.mode == .Debug and logging) {
        var debug: std.ArrayList(u8) = .empty;
        try debug.print(a, "PYTHONPATH={s} ", .{pythonpath_string.items});
        for (child.argv) |arg| {
            try debug.print(a, "{s} ", .{arg});
        }
        std.log.info("I'm going to run this command: {s}", .{debug.items});
    }

    child.stdin_behavior = .Ignore;

    if (logging) {
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
    } else {
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
    }

    try child.spawn();
    switch (try child.wait()) {
        .Exited => |val| return val,
        else => return error.ChildDidNotExit,
    }
    unreachable;
}
