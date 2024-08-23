const std = @import("std");
const utils = @import("../comptime_utils.zig");

const Super = @import("../obj.zig").Obj;
const Error = Super.Error;

pub const Closure = packed struct {
    const Self = @This();

    pub const Arg = *const Super.Function;

    obj: Super,
    function: *const Super.Function,

    pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.Closure,
            },
            .function = arg,
        };
        return self;
    }

    pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
        return @ptrCast(self);
    }

    pub fn format(self: *const Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        _ = try writer.write("<C: ");
        if (self.function.name) |name| {
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
        allocator.destroy(self);
    }
};
