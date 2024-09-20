const std = @import("std");
const chunk = @import("../chunk.zig");
const utils = @import("../comptime_utils.zig");

const Super = @import("../obj.zig").Obj;
const String = Super.String;

pub const Function = packed struct {
    const Self = @This();
    pub const Arg = Type;
    pub const Error = error { OutOfMemory };

    pub const Type = enum(u8) {
        Function,
        Script
    };

    obj: Super,
    arity: u8,
    chunk: *chunk.Chunk,
    name: ?*const String,
    type: Type,
    upvalue_count: u8,

    pub fn init(tp: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super.make(Self),
            .chunk = try allocator.create(chunk.Chunk),
            .arity = 0,
            .name = null,
            .type = tp,
            .upvalue_count = 0,
        };
        self.chunk.* = try chunk.Chunk.init(allocator);
        return self;
    }

    pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
        return @ptrCast(self);
    }

    pub fn format(self: *const Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch(self.type) {
            .Function => _ = try writer.write("<F: "),
            .Script => _ = try writer.write("<S: "),
        }
        if (self.name) |name| {
            _ = try writer.write(name.slice());
        } else {
            _ = try writer.write("-");
        }
        _ = try writer.writeAll(">");
    }

    pub fn eql(_: *const Self, _: *const Self) bool {
        return false;
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        self.chunk.deinit();
        allocator.destroy(self.chunk);
        allocator.destroy(self);
    }

};
