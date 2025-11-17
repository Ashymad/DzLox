const std = @import("std");
const utils = @import("comptime_utils.zig");

fn nameOf(fqn: []const u8) []const u8 {
    var lastDot = 0;
    for(fqn, 0..) |c, i| {
        if (c == '.') lastDot = i + 1;
        if (c == '(') return fqn[lastDot..i];
    }
    return fqn;
}

pub fn Obj(fields: anytype) type {
    return packed struct {
        const Self = @This();

        type: Type,
        fields: utils.make_packed_t(@TypeOf(fields)) = utils.make_packed(fields),

        pub const List = @import("obj/list.zig").List(fields);
        pub const String = @import("obj/string.zig").String(fields);
        pub const Table = @import("obj/table.zig").Table(fields);
        pub const Function = @import("obj/function.zig").Function(fields);
        pub const Native = @import("obj/native.zig").Native(fields);
        pub const Closure = @import("obj/closure.zig").Closure(fields);
        pub const Upvalue = @import("obj/upvalue.zig").Upvalue(fields);

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

        pub fn isChild(T: type) bool {
            inline for(@typeInfo(Type).@"enum".fields) |field| {
                const U = @field(Self, field.name);
                if (T == U or T == *U or T == *const U) return true;
            }
            return false;
        }

        pub fn make(child: type) Self {
            return Self {
                .type = @field(Type, nameOf(@typeName(child))),
            };
        }

        pub fn init(comptime tp: Type, arg: tp.get().Arg, allocator: std.mem.Allocator) !*Self {
            return (try tp.get().init(arg, allocator)).cast();
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            switch (self.type) {
                inline else => |tp| try self._cast(tp).format(writer),
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
}
