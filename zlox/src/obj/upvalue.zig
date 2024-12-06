const std = @import("std");

const utils = @import("../comptime_utils.zig");
const Value = @import("../value.zig").Value;

pub fn Upvalue(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();

        pub const Arg = struct {val: *Value, slot: u8};
        pub const Error = error { OutOfMemory };

        obj: Super,
        location: *Value,
        closed: bool,
        slot: u8,

        pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .location = arg.val,
                .closed = false,
                .slot = arg.slot
            };
            return self;
        }

        pub fn close(self: *Self, allocator: std.mem.Allocator) Error!void {
            if (!self.closed) {
                const new = try allocator.create(Value);
                new.* = self.location.*;
                self.location = new;
                self.closed = true;
            }
        }


        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.print("<Upvalue{{{} at 0x{x}, {}, {}}}>", .{self.location.*, @intFromPtr(self.location), self.closed, self.slot});
        }

        pub fn eql(_: *const Self, _: *const Self) bool {
            return false;
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            if (self.closed) allocator.destroy(self.location);
            allocator.destroy(self);
        }
    };
}
