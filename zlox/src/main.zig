const std = @import("std");
const vm = @import("vm.zig");
const Linenoise = @import("linenoize").Linenoise;

pub fn main() anyerror!u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == std.heap.Check.ok);

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try repl(allocator);
    } else if (args.len == 2) {
        try runFile(allocator, args[1]);
    } else {
        std.debug.print("Usage: {s} [path]\n", .{args[0]});
        return 64;
    }

    return 0;
}

pub fn runFile(allocator: std.mem.Allocator, path: []const u8) anyerror!void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const text = try file.reader().readAllAlloc(allocator, 999999);
    defer allocator.free(text);
}

pub fn repl(allocator: std.mem.Allocator) anyerror!void {
    var ln = Linenoise.init(allocator);
    defer ln.deinit();

    var VM = vm.VM.init();
    defer VM.deinit();

    while (try ln.linenoise("lox> ")) |input| {
        defer allocator.free(input);
        try VM.interpret(input);
        try ln.history.add(input);
    }
}
