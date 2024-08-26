const std = @import("std");

const Obj = @import("obj.zig").Obj;
const list = @import("list.zig");
const Value = @import("value.zig").Value;

pub const GC = struct {
    const Self = @This();

    const List = list.List(*Obj);

    allocator: std.mem.Allocator,
    table: Obj.String.Table,
    list: List,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .table = Obj.String.Table.init(allocator),
            .list = List.init(allocator),
        };
    }

    pub fn emplace(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) (List.Error || tp.get().Error)!*tp.get() {
        var newObj = true;
        const obj = switch (tp) {
            .String => try Obj.String.intern(arg, &self.table, &newObj, self.allocator),
            else => try tp.get().init(arg, self.allocator),
        };
        if (newObj) try self.list.push(obj.cast());
        return obj;
    }

    pub fn emplace_cast(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) (List.Error || tp.get().Error)!*Obj {
        return (try self.emplace(tp, arg)).cast();
    }

    pub fn deinit(self: *Self) void {
        while (true) {
            const el = self.list.pop() catch break;
            el.free(self.allocator);
        }
        self.list.free();
        self.table.deinit();
    }
};
