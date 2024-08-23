const std = @import("std");

const utils = @import("../comptime_utils.zig");
const Super = @import("../obj.zig").Obj;
const Error = Super.Error;

pub const Template = packed struct {
    const Self = @This();

    pub const Arg = void;

    obj: Super,
    pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
        _ = arg;
        _ = allocator;
        return error.OutOfMemory;
    }

    pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
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
        _ = self;
        _ = allocator;
    }
};

