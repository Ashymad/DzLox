const std = @import("std");
const array = @import("array.zig");

pub const Value = f64;

pub const ParseValueError = std.fmt.ParseFloatError;

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}

pub fn parseValue(str: []const u8) ParseValueError!Value {
    return std.fmt.parseFloat(Value, str);
}

pub const ValueArray = array.Array(Value, u8, 8);
