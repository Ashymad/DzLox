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
        prev: ?*@This(),
    };

    pub const Arg = void;

    obj: Super,
    len: usize = 0,
    tip: ?*Element,
    end: ?*Element,

    pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.List,
            },
            .tip = null,
            .end = null,
        };
        return self;
    }

    pub fn cast(self: *Self) *Super {
        return @ptrCast(self);
    }

    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) utils.fn_error(@TypeOf(writer).write)!void {
        _ = try writer.write("[");
        var end = self.end;
        while (end) |el| : (end = el.prev) {
            try el.val.format(fmt, options, writer);
            if (el.prev) |_| _ = try writer.write(", ");
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
        var idx_rev: usize = @intFromFloat(index.number);
        var idx = self.len - idx_rev;
        idx_rev += 1;

        if (idx < idx_rev) {
            var tip = self.tip;
            while(idx > 1) : (idx -= 1) {
                tip = tip.?.next;
            }
            return tip.?.val;
        } else {
            var end = self.end;
            while(idx_rev > 1) : (idx_rev -= 1) {
                end = end.?.prev;
            }
            return end.?.val;
        }
    }

    pub fn set(self: *Self, index: Value, val: Value, allocator: std.mem.Allocator) !void {
        if (!index.is(Value.number) or index.number < 0) {
            return error.KeyError;
        }

        var idx_rev: isize = @intFromFloat(index.number);
        var idx: isize = @as(isize, @intCast(self.len)) - idx_rev;
        idx_rev += 1;

        if (idx <= 0) {
            while(idx < 0) : (idx += 1) {
                try self.push(Value.init({}), allocator);
            }
            try self.push(val, allocator);
        } else if (idx < idx_rev) {
            var tip = self.tip;
            while(idx > 1) : (idx -= 1) {
                tip = tip.?.next;
            }
            tip.?.val = val;
        } else {
            var end = self.end;
            while(idx_rev > 1) : (idx_rev -= 1) {
                end = end.?.prev;
            }
            end.?.val = val;
        }

    }

    pub fn pop(self: *Self, allocator: std.mem.Allocator) ?Value {
        if (self.tip) |tip| {
            if (tip.next) |next| {
                next.prev = null;
                self.tip = next;
            } else {
                self.tip = null;
                self.end = null;
            }
            self.len -= 1;
            const val = tip.val;
            allocator.destroy(tip);
            return val;
        }
        return null;
    }

    pub fn push(self: *Self, val: Value, allocator: std.mem.Allocator) Error!void {
        const new_tip = try allocator.create(Element);
        if (self.end == null) {
            self.end = new_tip;
        }
        if (self.tip) |old_tip| {
            old_tip.prev = new_tip;
        }
        new_tip.* = Element{.val = val, .next = self.tip, .prev = null};
        self.tip = new_tip;
        self.len += 1;
    }

    pub fn push_end(self: *Self, val: Value, allocator: std.mem.Allocator) Error!void {
        const new_end = try allocator.create(Element);
        if (self.tip == null) {
            self.tip = new_end;
        }
        if (self.end) |old_end| {
            old_end.next = new_end;
        }
        new_end.* = Element{.val = val, .next = null, .prev = self.end};
        self.end = new_end;
        self.len += 1;
    }
};
