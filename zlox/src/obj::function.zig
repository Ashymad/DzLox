const std = @import("std");

const utils = @import("lib::utils.zig");

const Packed = @import("lib::packed.zig").Packed;
const Obj = @import("obj.zig").Obj;

pub fn Function(fields: anytype) type {
    const Super = Obj(fields);

    return packed struct {
        const Self = @This();

        pub const Error = error{ OutOfMemory, InvalidArguments };

        pub const Chunk = *Super.Chunk;
        pub const Upvalue = ?*Super.Upvalue;

        pub const Arg = struct {
            upvalues: u8 = 0,
            chunk: Chunk,
            arity: u8 = 0,
        };

        obj: Super,
        arity: u8,
        chunk: Packed(*Super.Chunk),
        upvalues: Packed([]Upvalue),

        pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* = Self{
                .obj = Super.make(Self),
                .chunk = Packed(Chunk).init(arg.chunk),
                .arity = arg.arity,
                .upvalues = try Packed([]Upvalue).create(allocator, arg.upvalues),
            };

            for (self.upvalues.ptr()) |*upvalue| upvalue.* = null;
            return self;
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            _ = try writer.print("{d}", .{self.upvalues.len()});
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            self.upvalues.destroy(allocator);
            allocator.destroy(self);
        }
    };
}
