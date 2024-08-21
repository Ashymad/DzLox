const std = @import("std");
const GC = @import("../gc.zig").GC;
const Value = @import("../value.zig").Value;
pub const NativeError = @import("../obj/native.zig").NativeError;

pub const Clock = struct {
    var start: std.time.Instant = undefined;

    pub fn set_start() !void {
        start = try std.time.Instant.now();
    }

    pub fn clock(_: *GC, _: [] const Value) NativeError!Value {
        const now = std.time.Instant.now() catch return NativeError.NativeError;
        const elapsed: f64 = @floatFromInt(now.since(start));
        return Value.init(elapsed / std.time.ns_per_s);
    }
};


pub fn put(_: *GC, args: []const Value) NativeError!Value {
    std.debug.print("{s}", .{args[0]});
    return Value.init({});
}

pub fn table(gc: *GC, args: []const Value) NativeError!Value {
    var tbl = gc.emplace(.Table, {}) catch return NativeError.NativeError;
    if (args.len % 2 != 0) return NativeError.NativeError;
    var i: usize = 0;
    while(i < args.len) : (i += 2) {
        _ = tbl.set(args[i], args[i+1]) catch return NativeError.NativeError;
    }
    return Value.init(tbl.cast());
}

pub fn list(gc: *GC, args: []const Value) NativeError!Value {
    var lis = gc.emplace(.List, {}) catch return NativeError.NativeError;
    for(args) |arg| {
        lis.push(arg, gc.allocator) catch return NativeError.NativeError;
    }
    return Value.init(lis.cast());
}
