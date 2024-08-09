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

    pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.Function,
            },
            .chunk = try allocator.create(chunk.Chunk),
            .arity = 0,
        };
        self.chunk.* = chunk.Chunk.init(allocator);
        return self;
    }

    pub fn cast(self: *Self) *Super {
        return @ptrCast(self);
    }

    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = self;
        _ = fmt;
        _ = options;
        _ = writer;
    }

    pub fn eql(self: *const Self, other: *const Self) bool {
        _ = self;
        _ = other;
        return false;
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        self.chunk.deinit();
        allocator.destroy(self.chunk);
        allocator.destroy(self);
    }

};
