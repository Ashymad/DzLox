const std = @import("std");

const Value = @import("../value.zig").Value;
const Super = @import("../obj.zig").Obj;
const utils = @import("../comptime_utils.zig");
const Error = Super.Error;
const String = Super.String;
const Type = Super.Type;

pub const List = packed struct {
    const Self = @This();

    const Element = struct {
        val: Value,
        next: ?*@This(),
    };

    pub const Arg = void;

    obj: Super,
    len: usize = 0,
    tip: ?*Element,

    pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.List,
            },
            .tip = null,
        };
        return self;
    }

    pub fn cast(self: *Self) *Super {
        return @ptrCast(self);
    }

    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) utils.fn_error(@TypeOf(writer).write)!void {
        _ = try writer.write("[");
        var tip = self.tip;
        while (tip) |el| : (tip = el.next) {
            try el.val.format(fmt, options, writer);
        _ = try writer.write(",");
        }
        _ = try writer.writeAll("]");
    }

    pub fn eql(self: *const Self, other: *const Self) bool {
        if (self.len != other.len) return false;
        if (self.len == 0) return true;
        var tip1 = self.tip;
        var tip2 = other.tip;
        while (tip1) |el1| : (tip1 = el1.next) {
            if (!el1.val.eql(tip2.?.val))
                return false;
            tip2 = tip2.?.next;
        }
        return true;
    }

    pub fn free(self: *Self, allocator: std.mem.Allocator) void {
        while (self.pop(allocator)) |_| {}
        allocator.destroy(self);
    }

    pub fn get(self: *const Self, index: Value) !Value {
        if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(self.len)) or index.number < 0) {
            return error.KeyError;
        }
        var idx = self.len - @as(usize, @intFromFloat(index.number));
        var tip = self.tip;
        while(idx > 1) : (idx -= 1) {
            tip = tip.?.next;
        }
        return tip.?.val;
    }

    pub fn pop(self: *Self, allocator: std.mem.Allocator) ?Value {
        if (self.tip) |tip| {
            self.tip = tip.next;
            self.len -= 1;
            const val = tip.val;
            allocator.destroy(tip);
            return val;
        }
        return null;
    }

    pub fn push(self: *Self, val: Value, allocator: std.mem.Allocator) Error!void {
        var new_tip = try allocator.create(Element);
        new_tip.next = self.tip;
        new_tip.val = val;
        self.tip = new_tip;
        self.len += 1;
    }
};
