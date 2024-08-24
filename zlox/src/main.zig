const std = @import("std");
const vm = @import("vm.zig");
const Linenoise = @cImport({
    @cInclude("stddef.h");
    @cInclude("linenoise.h");
});

pub fn main() anyerror!u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == std.heap.Check.ok);

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try repl(allocator, false);
    } else if (args.len == 2) {
        if (std.mem.eql(u8, args[1], "-d")) {
            try repl(allocator, true);
        } else {
            try runFile(allocator, args[1]);
        }
    } else {
        std.debug.print("Usage: {s} [path]\n", .{args[0]});
        return 64;
    }

    return 0;
}

pub fn runFile(allocator: std.mem.Allocator, path: []const u8) anyerror!void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var VM = try vm.VM.init(allocator);
    defer VM.deinit();

    const text = try file.reader().readAllAlloc(allocator, 999999);
    defer allocator.free(text);

    try VM.interpret(text, true);
}

pub fn repl(allocator: std.mem.Allocator, dbg: bool) anyerror!void {
    var VM = try vm.VM.init(allocator);
    defer VM.deinit();

    _ = Linenoise.linenoiseHistorySetMaxLen(100);

    while (Linenoise.linenoise("lox> ")) |line| {
        defer Linenoise.linenoiseFree(line);
        VM.interpret(std.mem.span(line), dbg) catch |err| {
            std.debug.print("\nError: {}\n", .{err});
        };
        _ = Linenoise.linenoiseHistoryAdd(line);
    }
}
