const std = @import("std");
const chunk = @import("../chunk.zig");

const Super = @import("../obj.zig").Obj;
const Error = Super.Error;
const String = Super.String;

pub const Function = packed struct {
    const Self = @This();
    pub const Arg = void;

    obj: Super,
    arity: u8,
    chunk: *chunk.Chunk,
    name: *String,

    pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
        _ = arg;
        _ = allocator;
        return error.OutOfMemory;
    }

    pub fn cast(self: *Self) *Super {
        return @ptrCast(self);
    }

    pub fn print(self: *const Self) void {
        _ = self;
    }

    pub fn eql(self: *const Self, other: *const Self) bool {
        _ = self;
        _ = other;
        return false;
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

};
