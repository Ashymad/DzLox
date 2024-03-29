const std = @import("std");
const utils = @import("comptime_utils.zig");
const hash = @import("hash.zig").hash;

pub const Obj = packed struct {
    const Super = @This();
    pub const Error = error{IllegalCastError};

    type: Type,
    next: ?*Super = null,
    hash: u32,

    pub const List = struct {};

    pub const String = packed struct {
        const Self = @This();
        const Arg = []const u8;

        obj: Super,
        len: usize,

        fn data(self: anytype) utils.copy_const(@TypeOf(self), [*]u8) {
            const p: utils.copy_const(@TypeOf(self), [*]u8) = @ptrCast(self);
            return p + @sizeOf(Self);
        }
        fn new(len: usize, allocator: std.mem.Allocator) !*Self {
            const ret: *Self = @ptrCast(try allocator.alignedAlloc(u8, @alignOf(Self), @sizeOf(Self) + len));
            ret.* = Self{ .obj = Super{
                .type = Super.Type.String,
                .hash = 0,
            }, .len = len };
            return ret;
        }
        fn rehash(self: *Self) void {
            self.obj.hash = hash(self.slice());
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.data()[0..self.len];
        }
        pub fn cat(self: *const Self, other: *const Self, allocator: std.mem.Allocator) !*Self {
            var ret = try new(self.len + other.len, allocator);
            @memcpy(ret.data(), self.slice());
            @memcpy(ret.data() + self.len, other.slice());
            ret.rehash();
            return ret;
        }

        pub fn cast(self: *Self) *Super {
            return @ptrCast(self);
        }
        pub fn print(self: *const Self) void {
            std.debug.print("\"{s}\"", .{self.slice()});
        }
        pub fn eql(self: *const Self, other: *const Self) bool {
            return @intFromPtr(self) == @intFromPtr(other);
        }
        pub fn init(string: Arg, allocator: std.mem.Allocator) !*Self {
            var ret = try new(string.len, allocator);
            @memcpy(ret.data(), string);
            ret.rehash();
            return ret;
        }
        fn free(self: *const Self, allocator: std.mem.Allocator) void {
            const p: [*]align(@alignOf(Self)) const u8 = @ptrCast(self);
            allocator.free(p[0 .. @sizeOf(Self) + self.len]);
        }
    };

    pub const Type = enum {
        String,

        pub fn get(comptime self: @This()) type {
            return @field(Super, @tagName(self));
        }
    };

    pub fn init(comptime tp: Type, arg: tp.get().Arg, allocator: std.mem.Allocator) !*Super {
        return (try tp.get().init(arg, allocator)).cast();
    }
    pub fn print(self: *const Super) void {
        switch (self.type) {
            inline else => |tp| self._cast(tp).print(),
        }
    }
    pub fn eql(self: *const Super, other: *const Super) bool {
        if (!self.is(other.type)) return false;
        return switch (self.type) {
            inline else => |tp| self._cast(tp).eql(other._cast(tp)),
        };
    }
    pub fn free(obj: *Super, allocator: std.mem.Allocator) void {
        return switch (obj.type) {
            inline else => |tp| obj._cast(tp).free(allocator),
        };
    }

    pub fn is(self: *const Super, tp: Type) bool {
        return self.type == tp;
    }

    pub fn cast(self: *const Super, comptime tp: Type) Error!*const tp.get() {
        if (!self.is(tp)) return Error.IllegalCastError;
        return self._cast(tp);
    }

    fn _cast(self: *const Super, comptime tp: Type) *const tp.get() {
        return @ptrCast(@alignCast(self));
    }
};
