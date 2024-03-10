const std = @import("std");
const value = @import("value.zig");
const ValueArray = value.ValueArray;
const array = @import("array.zig");

pub const OP = enum(u8) {
    CONSTANT,
    NIL,
    TRUE,
    FALSE,
    RETURN,
    NEGATE,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NOT,
};

pub const ChunkError = error{OutOfMemory};

pub const Chunk = struct {
    pub fn init(allocator: std.mem.Allocator) ChunkError!@This() {
        return @This(){
            .code = try array.Array(u8, usize, 8).init(allocator),
            .constants = try ValueArray.init(allocator),
            .lines = try array.RLEArray(i32, 8).init(allocator),
        };
    }

    pub fn write(self: *@This(), byte: u8, line: i32) ChunkError!void {
        try self.code.add(byte);
        try self.lines.add(line);
    }

    pub fn writeOP(self: *@This(), op: OP, line: i32) ChunkError!void {
        try self.write(@intFromEnum(op), line);
    }

    pub fn addConstant(self: *@This(), val: value.Value) ChunkError!u8 {
        try self.constants.add(val);
        return self.constants.len - 1;
    }

    pub fn deinit(self: *@This()) void {
        self.constants.deinit();
        self.lines.deinit();
        self.code.deinit();
    }

    code: array.Array(u8, usize, 8),
    constants: ValueArray,
    lines: array.RLEArray(i32, 8),
};
