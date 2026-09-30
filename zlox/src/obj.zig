const std = @import("std");

const utils = @import("lib::utils.zig");
const Value = @import("value.zig").Value;

pub fn Obj(Fields: type) type {
    return packed struct {
        const Self = @This();

        type: Type,
        fields: Fields = Fields{},

        pub const List = @import("obj::list.zig").List(Fields);
        pub const String = @import("obj::string.zig").String(Fields);
        pub const Table = @import("obj::table.zig").Table(Fields);
        pub const Function = @import("obj::function.zig").Function(Fields);
        pub const Native = @import("obj::native.zig").Native(Fields);
        pub const Chunk = @import("obj::chunk.zig").Chunk(Fields);
        pub const Upvalue = @import("obj::upvalue.zig").Upvalue(Fields);
        pub const Class = @import("obj::class.zig").Class(Fields);
        pub const Instance = @import("obj::instance.zig").Instance(Fields);

        pub const Error = error{IllegalCastError} //
            || List.Error //
            || String.Error //
            || Table.Error //
            || Function.Error //
            || Native.Error //
            || List.Error //
            || Chunk.Error //
            || Upvalue.Error //
            || Class.Error //
            || Instance.Error;

        pub const Type = enum(u8) {
            String,
            Table,
            Function,
            Native,
            List,
            Chunk,
            Upvalue,
            Class,
            Instance,

            pub fn get(self: @This()) type {
                return @field(Self, @tagName(self));
            }
        };

        fn child_name(fqn: []const u8) []const u8 {
            var lastDot = 0;
            for (fqn, 0..) |c, i| {
                if (c == '.') lastDot = i + 1;
                if (c == '(') return fqn[lastDot..i];
            }
            return fqn;
        }

        pub fn is_child(T: type) bool {
            inline for (std.meta.tags(Type)) |tag| {
                if (*tag.get() == T) return true;
            }
            return false;
        }

        pub fn make(child: type) Self {
            return Self{
                .type = @field(Type, child_name(@typeName(child))),
            };
        }

        pub fn init(comptime tp: Type, arg: tp.get().Arg, allocator: std.mem.Allocator) !*Self {
            return (try tp.get().init(arg, allocator)).cast();
        }

        pub fn format(self: anytype, writer: *std.Io.Writer) !void {
            _ = try writer.write("<");
            switch (self.type) {
                inline else => |tp| {
                    _ = try writer.write(@tagName(tp)[0..2]);
                    if (@hasDecl(tp.get(), "format")) {
                        _ = try writer.write(":");
                        try self._cast(tp).format(writer);
                    }
                },
            }
            if (@hasDecl(Fields, "format")) {
                try self.fields.format(writer);
            }
            _ = try writer.write(">");
        }

        pub fn eql(self: *const Self, other: *const Self) bool {
            if (!self.is(other.type)) return false;

            return switch (self.type) {
                inline else => |tp| if (@hasDecl(tp.get(), "eql")) self._cast(tp).eql(other._cast(tp)) else false,
            };
        }

        pub fn free(obj: *Self, allocator: std.mem.Allocator) void {
            return switch (obj.type) {
                inline else => |tp| obj._cast(tp).free(allocator),
            };
        }

        pub fn from(arg: anytype) ?*Self {
            const T = @TypeOf(arg);

            return switch (T) {
                Value => switch (arg) {
                    .obj => |o| Self.from(o),
                    else => null,
                },
                *Self => arg,
                else => if (comptime Self.is_child(T)) arg.cast() else null,
            };
        }

        pub fn is(self: *const Self, tp: Type) bool {
            return self.type == tp;
        }

        pub fn cast(self: anytype, comptime tp: Type) Error!utils.copy_const(@TypeOf(self), *tp.get()) {
            return if (self.is(tp)) self._cast(tp) else Error.IllegalCastError;
        }

        pub fn cast_if(self: anytype, comptime tp: Type) ?utils.copy_const(@TypeOf(self), *tp.get()) {
            return if (self.is(tp)) self._cast(tp) else null;
        }

        fn _cast(self: anytype, comptime tp: Type) utils.copy_const(@TypeOf(self), *tp.get()) {
            return @ptrCast(@alignCast(self));
        }
    };
}
