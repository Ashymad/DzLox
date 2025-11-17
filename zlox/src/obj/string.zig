const std = @import("std");
const table = @import("../table.zig");
const hash = @import("../hash.zig");
const utils = @import("../comptime_utils.zig");
const value = @import("../value.zig");

pub fn String(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();
        pub const Table = table.Table(*Self, void, hash.hash_t(*const Self), Self.eql);
        pub const Arg = []const []const u8;
        pub const Error = error { OutOfMemory, IndexOutOfBounds } || Table.Error;

        obj: Super,
        len: usize = 0,
        hash: u32,

        fn data(self: anytype) utils.copy_const(@TypeOf(self), [*]u8) {
            const p: utils.copy_const(@TypeOf(self), [*]u8) = @ptrCast(self);
            return p + @sizeOf(Self);
        }
        fn new(arg: Arg, params: ArgParams, allocator: std.mem.Allocator) Error!*Self {
            const ret: *Self = @ptrCast(try allocator.alignedAlloc(u8, std.mem.Alignment.of(Self), @sizeOf(Self) + params.len));
            ret.* = Self{
                .obj = Super.make(Self),
                .hash = params.hash,
            };
            for (arg) |el| {
                @memcpy(ret.data() + ret.len, el);
                ret.len += el.len;
            }
            return ret;
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.data()[0..self.len];
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            _ = try writer.writeAll(self.slice());
        }
        pub fn eql(self: *const Self, other: *const Self) bool {
            return @intFromPtr(self) == @intFromPtr(other);
        }
        pub fn get(self: *const Self, index: value.Value) Error!value.Value {
            if (!index.is(value.Value.number) or index.number >= @as(value.Value.tagType(value.Value.number), @floatFromInt(self.len)) or index.number < 0) {
                return Error.IndexOutOfBounds;
            }
            return value.Value.init(self.data()[@intFromFloat(index.number)]);
        }

        const ArgParams = struct { len: usize, hash: u32 };

        fn table_check(m_arg: Arg, m_params: ArgParams) struct {
            arg: Arg,
            params: ArgParams,
            pub fn check(self: *const @This(), k2: *const Self) bool {
                if (k2.hash == self.params.hash and k2.len == self.params.len) {
                    var idx: usize = 0;
                    for (self.arg) |el| {
                        if (!std.mem.eql(u8, k2.data()[idx .. idx + el.len], el))
                        return false;
                        idx += el.len;
                    }
                    return true;
                }
                return false;
            }
        } {
            return @TypeOf(table_check(m_arg, m_params)){ .arg = m_arg, .params = m_params };
        }

        fn arg_params(arg: Arg) ArgParams {
            var ret = ArgParams{ .len = 0, .hash = hash.hash_t([]const u8)(&.{}) };

            for (arg) |el| {
                ret.len += el.len;
                ret.hash = hash.hash_append(ret.hash, el);
            }
            return ret;
        }

        pub fn intern(arg: Arg, tabl: *Self.Table, isNewKey: *bool, allocator: std.mem.Allocator) Error!*Self {
            const params = arg_params(arg);

            try tabl.checkCapacity();
            const entry = Self.Table.find_(tabl.entries, params.hash, table_check(arg, params));
            isNewKey.* = entry.* != Self.Table.Entry.some;
            if (isNewKey.*) {
                _ = tabl.set_(entry, try new(arg, params, allocator), {});
            }
            return entry.some.key;
        }

        pub fn init(_: Arg, _: std.mem.Allocator) Error!*Self {
            @compileError("The String Obj has to be interned");
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            const p: [*]align(@alignOf(Self)) const u8 = @ptrCast(self);
            allocator.free(p[0 .. @sizeOf(Self) + self.len]);
        }
    };
}
