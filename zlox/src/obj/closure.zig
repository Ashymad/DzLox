const std = @import("std");
const utils = @import("../comptime_utils.zig");

pub fn Closure(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();

        pub const Arg = *const Super.Function;
        pub const Error = error { OutOfMemory };

        obj: Super,
        function: *const Super.Function,
        upvalues: [*]?*Super.Upvalue,
        upvalues_len: u8,

        pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .upvalues = (try allocator.alloc(?*Super.Upvalue, arg.upvalue_count)).ptr,
                .upvalues_len = arg.upvalue_count,
                .function = arg,
            };
            for(self.upvalues[0..self.upvalues_len])
                |*upvalue| upvalue.* = null;
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
            allocator.free(self.upvalues[0..self.upvalues_len]);
            allocator.destroy(self);
        }
    };
}
