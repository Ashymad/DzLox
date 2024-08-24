const std = @import("std");

const utils = @import("../comptime_utils.zig");
const Value = @import("../value.zig").Value;
const Super = @import("../obj.zig").Obj;
const Error = Super.Error;

pub const Upvalue = packed struct {
    const Self = @This();

    pub const Arg = *Value;

    obj: Super,
    location: *Value,

    pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.Upvalue,
            },
            .location = arg,
        };
        return self;
    }

    pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
        return @ptrCast(self);
    }

    pub fn format(_: *const Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        _ = try writer.writeAll("<upvalue>");
    }

    pub fn eql(_: *const Self, _: *const Self) bool {
        return false;
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

