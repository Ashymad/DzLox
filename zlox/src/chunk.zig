const std = @import("std");
const value = @import("value.zig");
const ValueArray = value.ValueArray;
const array = @import("array.zig");
const Obj = @import("obj.zig").Obj;

pub const OP = enum(u8) {
    CONSTANT,
    NIL,
    TRUE,
    FALSE,
    EQUAL,
    GREATER,
    LESS,
    RETURN,
    NEGATE,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NOT,
};

pub const Chunk = struct {
    pub const Error = error{OutOfMemory};

    pub fn init(allocator: std.mem.Allocator) Error!@This() {
        return @This(){
            .code = try array.Array(u8, usize, 8).init(allocator),
            .constants = try ValueArray.init(allocator),
            .lines = try array.RLEArray(i32, 8).init(allocator),
            .allocator = allocator,
            .objects = null,
        };
    }

    pub fn write(self: *@This(), byte: u8, line: i32) Error!void {
        try self.code.add(byte);
        try self.lines.add(line);
    }

    pub fn writeOP(self: *@This(), op: OP, line: i32) Error!void {
        try self.write(@intFromEnum(op), line);
    }

    pub fn addConstant(self: *@This(), val: value.Value) Error!u8 {
        try self.constants.add(val);
        self.addObject(val);
        return self.constants.len - 1;
    }

    pub fn addObject(self: *@This(), val: value.Value) void {
        if (val.is(value.Value.obj)) {
            val.obj.next = self.objects;
            self.objects = val.obj;
        }
    }

    pub fn deinit(self: *@This()) void {
        self.constants.deinit();
        self.lines.deinit();
        self.code.deinit();

        while (self.objects) |obj| {
            self.objects = obj.next;
            obj.free(self.allocator);
        }
    }

    objects: ?*Obj,
    allocator: std.mem.Allocator,
    code: array.Array(u8, usize, 8),
    constants: ValueArray,
    lines: array.RLEArray(i32, 8),
};
