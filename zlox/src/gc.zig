const std = @import("std");

const list = @import("list.zig");
const Value = @import("value.zig").Value;
const utils = @import("comptime_utils.zig");
const VM = @import("vm.zig").VM;

pub const GC = struct {
    pub const Obj = @import("obj.zig").Obj(.{ .mark = false });

    const Self = @This();

    const List = list.List(*Obj);

    pub const Callback = struct {
        pub const Arg = *anyopaque;
        pub const Fn = *const fn (Arg) void;

        arg: Arg,
        @"fn": Fn,

        pub fn call(self: *const @This()) void {
            self.@"fn"(self.arg);
        }
    };

    const DBG_STRESS = true;
    const DBG_LOG = true;

    allocator: std.mem.Allocator,
    io: std.Io,
    table: Obj.String.Table,
    list: List,
    callbacks: list.List(Callback),

    fn dbg_print(comptime fmt: []const u8, args: anytype) void {
        if (DBG_LOG) {
            std.debug.print("[GC] " ++ fmt, args);
        }
    }

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !Self {
        return Self{
            .allocator = allocator,
            .io = io,
            .table = Obj.String.Table.init(allocator),
            .list = List.init(allocator),
            .callbacks = list.List(Callback).init(allocator),
        };
    }

    fn collect(self: *Self) void {
        self.callbacks.for_each({}, struct {
            pub fn fun(cb_ptr: ?Callback) void {
                if (cb_ptr) |cb| {
                    cb.call();
                }
            }
        }.fun);
    }

    pub fn push_callback(self: *Self, callback: Callback.Fn, arg: Callback.Arg) !void {
        try self.callbacks.push(Callback{ .@"fn" = callback, .arg = arg });
    }

    pub fn pop_callback(self: *Self) void {
        _ = self.callbacks.pop() catch return;
    }

    pub fn dbg_obj(info: []const u8, obj: anytype, comptime prin: bool) void {
        if (prin) {
            dbg_print("[{s}] {s: <8} [{s}] 0x{x} {f}\n", .{
                info,
                @tagName(obj.type),
                if (obj.fields.mark) "X" else " ",
                @intFromPtr(obj),
                obj,
            });
        } else {
            dbg_print("[{s}] {s: <8} [{s}] 0x{x}\n", .{
                info,
                @tagName(obj.type),
                if (obj.fields.mark) "X" else " ",
                @intFromPtr(obj),
            });
        }
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
            dbg_obj("A", &obj.obj, true);
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
                dbg_obj("M", arg, true);

                arg.fields.mark = true;
                switch (arg.type) {
                    .Function => if ((arg.cast(.Function) catch unreachable).name.ptr()) |name| {
                        mark(name);
                    },
                    else => {},
                }
            },
            *const Obj => {
                dbg_obj("S", arg, true);
            },
            else => if (comptime Obj.isChild(T)) {
                mark(arg.cast());
            } else {
                @compileError("Unable to mark " ++ @typeName(T));
            },
        }
    }

    pub fn emplace_cast(self: *Self, comptime tp: Obj.Type, arg: tp.get().Arg) (List.Error || tp.get().Error)!*Obj {
        return (try self.emplace(tp, arg)).cast();
    }

    pub fn deinit(self: *Self) void {
        while (true) {
            const el = self.list.pop() catch break;
            dbg_obj("F", el, false);
            el.free(self.allocator);
        }
        self.callbacks.free();
        self.list.free();
        self.table.deinit();
    }
};
