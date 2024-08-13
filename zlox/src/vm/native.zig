const std = @import("std");
const Value = @import("../value.zig").Value;
var start: std.time.Instant = undefined;

pub fn set_start() !void {
    start = try std.time.Instant.now();
}

pub fn clock(_: [] const Value) Value {
    const now = std.time.Instant.now() catch unreachable;
    const elapsed: f64 = @floatFromInt(now.since(start));
    return Value.init(elapsed / std.time.ns_per_s);
}

pub fn put(args: []const Value) Value {
    std.debug.print("{s}", .{args[0]});
    return Value.init({});
}
