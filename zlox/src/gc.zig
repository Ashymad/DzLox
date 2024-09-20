const std = @import("std");

const Obj = @import("obj.zig").Obj;
const list = @import("list.zig");
const Value = @import("value.zig").Value;

pub const GC = struct {
    const Self = @This();

    const List = list.List(*Obj);

    const DBG_STRESS = true;
    const DBG_LOG = true;

    allocator: std.mem.Allocator,
    table: Obj.String.Table,
    list: List,

    fn dbg_print(comptime fmt: []const u8, args: anytype) void {
        if (DBG_LOG) {
            std.debug.print("[GC] " ++ fmt, args);
        }
    }

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .table = Obj.String.Table.init(allocator),
            .list = List.init(allocator),
        };
    }

    fn collect(self: *Self) void {
        dbg_print("Collection begin\n", .{});
        _ = self;
        dbg_print("Collection end\n", .{});
    }

    pub fn emplace(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) (List.Error || tp.get().Error)!*tp.get() {
        var newObj = true;
        const obj = switch (tp) {
            .String => try Obj.String.intern(arg, &self.table, &newObj, self.allocator),
            else => try tp.get().init(arg, self.allocator),
        };
        if (newObj) {
            if (DBG_STRESS) {
                // self.collect();
            }
            dbg_print("Allocating {} at 0x{x}: {s}\n", .{obj.obj.type, @intFromPtr(obj), obj});
            try self.list.push(obj.cast());
        }
        return obj;
    }

    pub fn emplace_cast(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) (List.Error || tp.get().Error)!*Obj {
        return (try self.emplace(tp, arg)).cast();
    }

    pub fn deinit(self: *Self) void {
        while (true) {
            const el = self.list.pop() catch break;
            dbg_print("Freeing {} at 0x{x}: {s}\n", .{el.type, @intFromPtr(el), el});
            el.free(self.allocator);
        }
        self.list.free();
        self.table.deinit();
    }
};
