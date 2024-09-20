const std = @import("std");

const utils = @import("../comptime_utils.zig");
const GC = @import("../gc.zig").GC;
const Value = @import("../value.zig").Value;
const Super = @import("../obj.zig").Obj;

pub const Native = packed struct {
    const Self = @This();
    pub const Error = error { OutOfMemory, Native };

    pub const Fn = *const fn (*GC, []const Value) Error!Value;

    pub const ArityMin = 0;
    pub const ArityMax = std.math.maxInt(u8);

    pub const Arg = struct {
        fun: Fn,
        arity_min: u8 = ArityMin,
        arity_max: u8 = ArityMax,
        name: []const u8 = ""
    };

    obj: Super,
    fun: Fn,
    arity_min: u8,
    arity_max: u8,
    name: [*]const u8,
    name_len: usize,

    pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super.make(Self),
            .fun = arg.fun,
            .arity_min = arg.arity_min,
            .arity_max = arg.arity_max,
            .name = arg.name.ptr,
            .name_len = arg.name.len
        };
        return self;
    }

    pub fn call(self: *const Self, gc: *GC, argCount: u8, args: [*]Value) Error!Value {
        return self.fun(gc, args[0..argCount]);
    }

    pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
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

