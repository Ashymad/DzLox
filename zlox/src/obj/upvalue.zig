const std = @import("std");

const utils = @import("../comptime_utils.zig");
const Value = @import("../value.zig").Value;
const pack = @import("../packed.zig");

pub fn Upvalue(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();

        pub const Arg = struct {val: *Value, slot: u8};
        pub const Error = error { OutOfMemory };

        obj: Super,
        location: pack.Packed(*Value),
        closed: bool,
        slot: u8,

        pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .location = pack.Packed(*Value).init(arg.val),
                .closed = false,
                .slot = arg.slot
            };
            return self;
        }

        pub fn close(self: *Self, allocator: std.mem.Allocator) Error!void {
            if (!self.closed) {
                const new = try allocator.create(Value);
                new.* = self.location.ptr().*;
                self.location = pack.Packed(*Value).init(new);
                self.closed = true;
            }
        }


        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            try writer.print("<Upvalue{{{f} at 0x{x}, {any}, {d}}}>", .{self.location.ptr().*, self.location._ptr, self.closed, self.slot});
        }

        pub fn eql(_: *const Self, _: *const Self) bool {
            return false;
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            if (self.closed) allocator.destroy(self.location.ptr());
            allocator.destroy(self);
        }
    };
}
