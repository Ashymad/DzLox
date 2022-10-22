const std = @import("std");
const value = @import("value.zig");
const ValueArray = value.ValueArray;
const RLEArray = @import("rlearray.zig").RLEArray;

pub const OP = enum(u8) {
    CONSTANT,
    RETURN,
};

pub const Chunk = struct {
    pub fn init(allocator: std.mem.Allocator) !@This() {
        const cap = 8;
        return @This() {
            .count = 0,
            .capacity = cap,
            .code = try allocator.alloc(u8, cap),
            .constants = try ValueArray.init(allocator),
            .lines = try RLEArray(u32).init(allocator),
            .allocator = allocator
        };
    }

    pub fn write(self: *@This(), byte: u8, line: u32) !void {
        if (self.capacity < self.count + 1) {
            self.capacity = 2 * self.count;
            self.code = try self.allocator.realloc(self.code, self.capacity);
        }
        self.code[self.count] = byte;
        try self.lines.add(line);
        self.count += 1;
    }

    pub fn addConstant(self: *@This(), val: value.Value) !u8 {
        try self.constants.write(val);
        return self.constants.count - 1;
    }

    pub fn deinit(self: *@This()) void {
        self.constants.deinit();
        self.lines.deinit();
        self.allocator.free(self.code);
    }

    count: usize,
    capacity: usize,
    code: []u8,
    constants: ValueArray,
    lines: RLEArray(u32),
    allocator: std.mem.Allocator,
};
