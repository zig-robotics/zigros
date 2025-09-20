const std = @import("std");
const builtin = @import("builtin");

// The adapter generator like much of rosidl uses an arguments file instead of direct command line
// arguments.  This program wraps that by taking all arguments as command line arguments and
// writing to an arguments file automatically. This both writes the args file and calls the
// adaptor generator in one program.
//
//  -P additional python paths to include
//  -D must be an IDL u tuple in the form of {idl file}:{path to file}
//  -N the name of the package
//  -O the output directory to put generated files
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
    var output_dir: ?[]const u8 = null;
    var python: ?[]const u8 = null;
    var non_idl_tuples: std.ArrayList([]const u8) = .empty;

    var python_path_args: std.ArrayList([]const u8) = .empty;

    var logging = false;

    for (args[1..]) |arg| if (arg.len < 2) {
        std.log.err("invalid argument, length must be greater than 2", .{});
        return error.InvalidArgument;
    } else if (std.mem.eql(u8, "-P", arg[0..2])) {
        try python_path_args.append(a, arg[2..]);
    } else if (std.mem.eql(u8, "-D", arg[0..2])) {
        var it = std.mem.tokenizeAny(u8, arg[2..], ":");
        const idl = it.next() orelse return error.IdlTupleEmpty;
        const path = it.next() orelse return error.IdlTupleMissingDelimiter;
        try non_idl_tuples.append(a, try std.fmt.allocPrint(arena.allocator(), "{s}:{s}", .{ path, idl }));
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

    const args_file_path = try std.fmt.allocPrint(arena.allocator(), "{s}/rosidl_type_adapter__arguments.json", .{
        output_dir orelse return error.OutputDirNotProvided,
    });
    var output_file = try std.fs.createFileAbsolute(args_file_path, .{});
    defer output_file.close();
    var output_file_buf: [4096]u8 = undefined;
    var json_writer = output_file.writer(&output_file_buf);

    var stringify = std.json.Stringify{ .writer = &json_writer.interface };
    try stringify.write(.{
        .non_idl_tuples = non_idl_tuples.items,
    });
    try json_writer.interface.flush();

    var child = std.process.Child.init(&.{
        python orelse return error.PythonExeNotProvided,
        "-m",
        "rosidl_adapter",
        "--arguments-file",
        args_file_path,
        "--package-name",
        package_name orelse return error.ProgramNameNotProvided,
        "--output-dir",
        output_dir orelse return error.OutputDirNotProvided,
        "--output-file",
        "/dev/null",
    }, arena.allocator());

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
