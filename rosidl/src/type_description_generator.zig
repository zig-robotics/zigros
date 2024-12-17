const std = @import("std");
const builtin = @import("builtin");

// Usage:
// The type description generator like much of rosidl uses an arguments file instead of direct
// command line arguments. This program wraps that by taking all arguments as command line
// arguments and writing to an arguments file automatically. This both writes the args file and
// calls the type description generator in one program.
//
//  -P additional python paths to include
//  -X the python executable to run
//  -I an interface file to convert
//  -N the name of the package
//  -O the output directory to put generated files
//  -B the python executable to run with
//  -l if passed, include logging when in debug build
pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (builtin.mode == .Debug) {
        _ = gpa.deinit();
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer if (builtin.mode == .Debug) {
        arena.deinit();
    };

    const args = try std.process.argsAlloc(arena.allocator());

    var package_name: ?[]const u8 = null;
    var output_dir: ?[]const u8 = null;
    var idl_tuples = std.ArrayList([]const u8).init(arena.allocator());
    var include_paths = std.ArrayList([]const u8).init(arena.allocator());

    var program: ?[]const u8 = null;
    var python_path_args = std.ArrayList([]const u8).init(arena.allocator());
    var python: ?[]const u8 = null;

    var logging = false;

    for (args[1..]) |arg| if (arg.len < 2) {
        std.log.err("invalid argument, length must be greater than 2", .{});
        return error.InvalidArgument;
    } else if (std.mem.eql(u8, "-P", arg[0..2])) {
        try python_path_args.append(arg[2..]);
    } else if (std.mem.eql(u8, "-X", arg[0..2])) {
        program = arg[2..];
    } else if (std.mem.eql(u8, "-D", arg[0..2])) {
        var it = std.mem.tokenizeAny(u8, arg[2..], ":");
        const idl = it.next() orelse return error.IdlTupleEmpty;
        const path = it.next() orelse return error.IdlTupleMissingDelimiter;
        try idl_tuples.append(try std.fmt.allocPrint(arena.allocator(), "{s}:{s}", .{ path, idl }));
    } else if (std.mem.eql(u8, "-I", arg[0..2])) {
        try include_paths.append(arg[2..]);
    } else if (std.mem.eql(u8, "-N", arg[0..2])) {
        if (package_name) |_| return error.MultiplePackageNamesProvided;
        package_name = arg[2..];
    } else if (std.mem.eql(u8, "-O", arg[0..2])) {
        if (output_dir) |_| return error.MultipleOutputDirsProvided;
        output_dir = arg[2..];
    } else if (std.mem.eql(u8, "-B", arg[0..2])) {
        if (python) |_| return error.MultiplePythonExecutablesProvided;
        python = arg[2..];
    } else if (std.mem.eql(u8, "-l", arg[0..2])) {
        logging = true;
        if (builtin.mode != .Debug) {
            std.log.info("Logging is set to true but build mode is not debug. Switch to debug to see logs.", .{});
        }
    };

    var json_args_str = std.ArrayList(u8).init(arena.allocator());

    try std.json.stringify(.{
        .package_name = package_name orelse return error.PackageNameNotProvided,
        .output_dir = output_dir orelse return error.OutputDirNotProvided,
        .idl_tuples = idl_tuples.items,
        .include_paths = include_paths.items,
    }, .{ .whitespace = .indent_2 }, json_args_str.writer());

    const args_file_path = try std.fmt.allocPrint(arena.allocator(), "{s}/rosidl_generator_type_description__arguments.json", .{
        output_dir orelse return error.OutputDirNotProvided,
    });
    var output_file = try std.fs.createFileAbsolute(args_file_path, .{});
    defer output_file.close();

    try output_file.writeAll(json_args_str.items);
    var child = std.process.Child.init(&.{
        python orelse return error.PythonExeNotProvided,
        program orelse return error.NoProgram,
        "--generator-arguments-file",
        args_file_path,
    }, arena.allocator());

    var pythonpath_string = std.ArrayList(u8).init(arena.allocator());
    var pythonpath_writer = pythonpath_string.writer();
    if (python_path_args.items.len > 0) {
        for (python_path_args.items) |python_path| {
            try pythonpath_writer.writeAll(python_path);
            try pythonpath_writer.writeAll(":");
        }
        // remove trailing :
        pythonpath_string.shrinkRetainingCapacity(pythonpath_string.items.len - 1);
    }
    var env = std.process.EnvMap.init(arena.allocator());
    try env.put("PYTHONPATH", pythonpath_string.items);
    child.env_map = &env;

    if (builtin.mode == .Debug and logging) {
        var debug = std.ArrayList(u8).init(arena.allocator());
        var writer = debug.writer();
        try writer.print("PYTHONPATH={s} ", .{pythonpath_string.items});
        for (child.argv) |arg| {
            try writer.print("{s} ", .{arg});
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
