const std = @import("std");

const Super = @import("../obj.zig").Obj;
const Error = Super.Error;
const String = Super.String;
const Type = Super.Type;

pub const List = struct {
    const Self = @This();
    const Element = struct {
        obj: *Super,
        next: ?*@This(),
    };

    tip: ?*Element,
    allocator: std.mem.Allocator,
    table: String.Table,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .tip = null, .allocator = allocator, .table = String.Table.init(allocator) };
    }

    pub fn push(self: *Self, val: *Super) Error!void {
        var new_tip = try self.allocator.create(Element);
        new_tip.next = self.tip;
        new_tip.obj = val;
        self.tip = new_tip;
    }

    pub fn emplace(self: *Self, comptime tp: Type, arg: tp.get().Arg) Error!*Super {
        var newObj = true;
        const obj = switch (tp) {
            .String => (try String.intern(arg, &self.table, &newObj, self.allocator)).cast(),
            else => try Super.init(tp, arg, self.allocator),
        };
        if (newObj) try self.push(obj);
        return obj;
    }

    pub fn pop(self: *Self) ?*Element {
        if (self.tip) |tip| {
            self.tip = tip.next;
            tip.obj.free(self.allocator);
            return tip;
        }
        return null;
    }

    pub fn deinit(self: *Self) void {
        while (self.pop()) |tip| {
            self.allocator.destroy(tip);
        }
        self.table.deinit();
    }
};
