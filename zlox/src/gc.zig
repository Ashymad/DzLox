const std = @import("std");

const list = @import("list.zig");
const Value = @import("value.zig").Value;

pub const GC = struct {
    pub const Obj = @import("obj.zig").Obj(.{ .mark = false });

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
                self.collect();
            }
            dbg_print("Allocating {any} at 0x{x}: {f}\n", .{ obj.obj.type, @intFromPtr(obj), obj });
            try self.list.push(obj.cast());
        }
        return obj;
    }

    pub fn markTable(table: anytype) void {
        const Table = @TypeOf(table);
        table.for_each({}, struct {
            pub fn fun(key: Table.Key, val: Table.Value) void {
                Self.mark(key);
                Self.mark(val);
            }
        }.fun);
    }

    pub fn markArray(arr: anytype) void {
        for (arr) |el| {
            Self.mark(el);
        }
    }

    pub fn mark(arg: anytype) void {
        const T = @TypeOf(arg);
        switch (T) {
            Value => switch (arg) {
                .obj => |o| {
                    mark(o);
                },
                else => {},
            },
            *Obj => {
                dbg_print("Marking {any} at 0x{x}: {f}\n", .{ arg.type, @intFromPtr(arg), arg });
                arg.fields.mark = true;
            },
            else => if (Obj.isChild(T)) {
                mark(arg.cast());
            },
        }
    }

    pub fn emplace_cast(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) (List.Error || tp.get().Error)!*Obj {
        return (try self.emplace(tp, arg)).cast();
    }

    pub fn deinit(self: *Self) void {
        while (true) {
            const el = self.list.pop() catch break;
            dbg_print("Freeing {any} at 0x{x}: {f}\n", .{ el.type, @intFromPtr(el), el });
            el.free(self.allocator);
        }
        self.list.free();
        self.table.deinit();
    }
};
