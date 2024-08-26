const std = @import("std");
const GC = @import("../gc.zig").GC;
const Value = @import("../value.zig").Value;

pub const Error = @import("../obj.zig").Obj.Native.Error;

pub const Clock = struct {
    var start: std.time.Instant = undefined;

    pub fn set_start() !void {
        start = try std.time.Instant.now();
    }

    pub fn clock(_: *GC, _: [] const Value) Error!Value {
        const now = std.time.Instant.now() catch return Error.Native;
        const elapsed: f64 = @floatFromInt(now.since(start));
        return Value.init(elapsed / std.time.ns_per_s);
    }
};


pub fn put(_: *GC, args: []const Value) Error!Value {
    std.debug.print("{s}", .{args[0]});
    return Value.init({});
}

pub fn table(gc: *GC, args: []const Value) Error!Value {
    var tbl = gc.emplace(.Table, {}) catch return Error.Native;
    if (args.len % 2 != 0) return Error.Native;
    var i: usize = 0;
    while(i < args.len) : (i += 2) {
        _ = tbl.set(args[i], args[i+1]) catch return Error.Native;
    }
    return Value.init(tbl.cast());
}

pub fn list(gc: *GC, args: []const Value) Error!Value {
    var lis = gc.emplace(.List, {}) catch return Error.Native;
    for(args) |arg| {
        lis.list.push(arg) catch return Error.Native;
    }
    return Value.init(lis.cast());
}
