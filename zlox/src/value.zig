const std = @import("std");
const array = @import("array.zig");

pub const Value = union(enum) {
    number: f64,
    bool: bool,
    nil: void,

    pub const Tag = std.meta.Tag(@This());

    pub fn print(self: @This()) void {
        switch (self) {
            .number => |val| std.debug.print("{d}", .{val}),
            .bool => |val| std.debug.print("{s}", .{if (val) "true" else "false"}),
            .nil => std.debug.print("nil", .{}),
        }
    }

    pub fn is(self: @This(), comptime tag: Tag) bool {
        return switch (self) {
            tag => true,
            else => false,
        };
    }

    pub fn new(comptime tag: Tag, value: tagType(tag)) @This() {
        var ret = @This(){ .number = undefined };
        ret.set(tag, value);
        return ret;
    }

    pub fn get(self: @This(), comptime tag: Tag) tagType(tag) {
        return @field(self, @tagName(tag));
    }

    pub fn set(self: *@This(), comptime tag: Tag, value: tagType(tag)) void {
        @field(self, @tagName(tag)) = value;
    }

    pub fn tagType(comptime tag: Tag) type {
        return @TypeOf(@field(@This(){ .number = undefined }, @tagName(tag)));
    }

    pub const ParseNumberError = std.fmt.ParseFloatError;

    pub fn parseNumber(str: []const u8) ParseNumberError!@This() {
        return @This(){ .number = try std.fmt.parseFloat(tagType(Value.number), str) };
    }

    pub fn isTruthy(self: @This()) bool {
        return switch (self) {
            .nil => false,
            .bool => |val| val,
            else => true,
        };
    }
};

pub const ValueArray = array.Array(Value, u8, 8);
