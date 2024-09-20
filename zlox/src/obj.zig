const std = @import("std");
const utils = @import("comptime_utils.zig");

fn nameOf(fqn: []const u8) []const u8 {
    if (std.mem.lastIndexOf(u8, fqn, ".")) |index| {
        return fqn[index + 1 ..];
    }
    return fqn;
}

pub const Obj = packed struct {
    const Self = @This();

    type: Type,
    marked: bool,

    pub const List = @import("obj/list.zig").List;
    pub const String = @import("obj/string.zig").String;
    pub const Table = @import("obj/table.zig").Table;
    pub const Function = @import("obj/function.zig").Function;
    pub const Native = @import("obj/native.zig").Native;
    pub const Closure = @import("obj/closure.zig").Closure;
    pub const Upvalue = @import("obj/upvalue.zig").Upvalue;

    pub const Error = error {IllegalCastError}
        || List.Error
        || String.Error
        || Table.Error
        || Function.Error
        || Native.Error
        || List.Error
        || Closure.Error
        || Upvalue.Error;

    pub const Type = enum(u8) {
        String,
        Table,
        Function,
        Native,
        List,
        Closure,
        Upvalue,

        pub fn get(comptime self: @This()) type {
            return @field(Self, @tagName(self));
        }
    };

    pub fn make(child: type) Self {
        return Self {
            .type = @field(Type, nameOf(@typeName(child))),
            .marked = false
        };
    }

    pub fn mark(self: *Self) void {
        self.marked = true;
        switch (self.type) {
            inline .List, .Table => |tp| self._cast(tp).mark(),
            else => {}
        }
    }

    pub fn init(comptime tp: Type, arg: tp.get().Arg, allocator: std.mem.Allocator) !*Self {
        return (try tp.get().init(arg, allocator)).cast();
    }

    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self.type) {
            inline else => |tp| try self._cast(tp).format(fmt, options, writer),
        }
    }
    pub fn eql(self: *const Self, other: *const Self) bool {
        if (!self.is(other.type)) return false;
        return switch (self.type) {
            inline else => |tp| self._cast(tp).eql(other._cast(tp)),
        };
    }
    pub fn free(obj: *Self, allocator: std.mem.Allocator) void {
        return switch (obj.type) {
            inline else => |tp| obj._cast(tp).free(allocator),
        };
    }

    pub fn is(self: *const Self, tp: Type) bool {
        return self.type == tp;
    }

    pub fn cast(self: anytype, comptime tp: Type) Error!utils.copy_const(@TypeOf(self), *tp.get()) {
        if (!self.is(tp)) return Error.IllegalCastError;
        return self._cast(tp);
    }

    fn _cast(self: anytype, comptime tp: Type) utils.copy_const(@TypeOf(self), *tp.get()) {
        return @ptrCast(@alignCast(self));
    }
};
