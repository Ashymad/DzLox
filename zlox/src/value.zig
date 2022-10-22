const std = @import("std");

pub const Value = f64;

pub fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}

pub const ValueArray = struct {
    pub fn init(allocator: std.mem.Allocator) !@This() {
        const cap = 8;
        return @This() {
            .count = 0,
            .capacity = cap,
            .values = try allocator.alloc(Value, cap),
            .allocator = allocator
        };
    }

    pub fn write(self: *@This(), byte: Value) !void {
        if (self.capacity < self.count + 1) {
            self.capacity = 2 * self.count;
            self.values = try self.allocator.realloc(self.values, self.capacity);
        }
        self.values[self.count] = byte;
        self.count += 1;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.values);
    }

    count: u8,
    capacity: u8,
    values: []Value,
    allocator: std.mem.Allocator,
};
