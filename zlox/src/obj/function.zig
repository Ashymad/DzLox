const std = @import("std");
const chunk = @import("../chunk.zig");
const utils = @import("../comptime_utils.zig");
const pack = @import("../packed.zig");

pub fn Function(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);
    const String = Super.String;

    return packed struct {
        const Self = @This();
        pub const Arg = Type;
        pub const Error = error { OutOfMemory };

        pub const Type = enum(u8) {
            Function,
            Script
        };

        obj: Super,
        arity: u8,
        chunk: pack.Packed(*chunk.Chunk),
        name: pack.Packed(?*const String),
        type: Type,
        upvalue_count: u8,

        pub fn init(tp: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .chunk = try pack.Packed(*chunk.Chunk).new(allocator),
                .arity = 0,
                .name = pack.Packed(?*const String).nil(),
                .type = tp,
                .upvalue_count = 0,
            };
            self.chunk.ptr().* = try chunk.Chunk.init(allocator);
            return self;
        }

        pub fn set_name(self: *Self, name: *const String) void {
            self.name = pack.Packed(?*const String).init(name);
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            switch(self.type) {
                .Function => _ = try writer.write("<F: "),
                .Script => _ = try writer.write("<S: "),
            }
            if (self.name.valid()) {
                _ = try writer.write(self.name.ptr().slice());
            } else {
                _ = try writer.write("-");
            }
            _ = try writer.writeAll(">");
        }

        pub fn eql(_: *const Self, _: *const Self) bool {
            return false;
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            self.chunk.ptr().deinit();
            self.chunk.free(allocator);
            allocator.destroy(self);
        }

    };
}
