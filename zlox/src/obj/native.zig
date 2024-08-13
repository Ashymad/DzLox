const std = @import("std");

const Value = @import("../value.zig").Value;
const Super = @import("../obj.zig").Obj;
const Error = Super.Error;

pub const Native = packed struct {
    const Self = @This();
    pub const Fn = *const fn ([]const Value) Value;

    pub const Arg = struct {
        fun: Fn,
        arity: u8,
        name: []const u8
    };

    obj: Super,
    fun: Fn,
    arity: u8,
    name: [*]const u8,
    name_len: usize,

    pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.Native,
            },
            .fun = arg.fun,
            .arity = arg.arity,
            .name = arg.name.ptr,
            .name_len = arg.name.len
        };
        return self;
    }

    pub fn call(self: *const Self, argCount: u8, args: [*]Value) Value {
        return self.fun(args[0..argCount]);
    }

    pub fn cast(self: *Self) *Super {
        return @ptrCast(self);
    }

    pub fn format(self: *const Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        _ = try writer.write("<N: ");
        _ = try writer.write(self.name[0..self.name_len]);
        _ = try writer.writeAll(">");
    }

    pub fn eql(_: *const Self, _: *const Self) bool {
        return false;
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

