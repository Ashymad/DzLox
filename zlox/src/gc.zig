const std = @import("std");

const Obj = @import("obj.zig").Obj;
const Value = @import("value.zig").Value;

pub const GC = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    table: Obj.String.Table,
    list: *Obj.List,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .table = Obj.String.Table.init(allocator),
            .list = try Obj.List.init({}, allocator),
        };
    }

    pub fn emplace(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) Obj.Error!*tp.get() {
        var newObj = true;
        const obj = switch (tp) {
            .String => try Obj.String.intern(arg, &self.table, &newObj, self.allocator),
            else => try tp.get().init(arg, self.allocator),
        };
        if (newObj) try self.list.push(Value.init(obj.cast()), self.allocator);
        return obj;
    }

    pub fn emplace_cast(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) Obj.Error!*Obj {
        return (try self.emplace(tp, arg)).cast();
    }

    pub fn deinit(self: *Self) void {
        while (self.list.pop(self.allocator)) |el| {
            el.obj.free(self.allocator);
        }
        self.list.free(self.allocator);
        self.table.deinit();
    }
};
