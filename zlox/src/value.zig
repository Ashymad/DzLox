const std = @import("std");
const array = @import("array.zig");

pub const Value = f64;

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}

pub const ValueArray = array.Array(Value, u8, 8);
