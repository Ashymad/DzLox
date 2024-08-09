const std = @import("std");
const table = @import("../table.zig");
const hash = @import("../hash.zig");
const value = @import("../value.zig");
const utils = @import("../comptime_utils.zig");

const Super = @import("../obj.zig").Obj;
const Error = Super.Error;

pub const Table = packed struct {
    const Self = @This();
    pub const Arg = void;
    const Table = table.Table(value.Value, value.Value, hash.hash_t(value.Value), value.Value.eql);

    obj: Super,
    table: *Self.Table,
    hash: u32,

    pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
        const self: *Self = try allocator.create(Self);
        self.* =  Self{
            .obj = Super{
                .type = Super.Type.Table,
            },
            .table = try allocator.create(Self.Table),
            .hash = 0,
        };
        self.table.* = Self.Table.init(allocator);
        return self;
    }
    pub fn cast(self: *Self) *Super {
        return @ptrCast(self);
    }

    pub fn set(self: *Self, key: value.Value, val: value.Value) !bool {
        self.hash +%= hash.hash(key) +% hash.hash(val);
        return self.table.set(key, val);
    }

    pub fn get(self: *Self, key: value.Value) !value.Value {
        return self.table.get(key);
    }

    pub fn delete(self: *Self, key: value.Value) void {
        const val = self.table.get(key) catch return;
        self.hash -%= hash.hash(key) -% hash.hash(val);
        _ = self.table.delete(key);
    }
    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const Printer = struct {
            options: std.fmt.FormatOptions,
            writer: @TypeOf(writer),

            pub fn print(this: @This(), key: value.Value, val: value.Value) utils.fn_error(@TypeOf(writer).write)!void {
                try key.format(fmt, this.options, this.writer);
                _ = try this.writer.write(":");
                try val.format(fmt, this.options, this.writer);
                _ = try this.writer.write(",");
            }

        };

        _ = try writer.write("[");
        try self.table.for_each_try(Printer{.options = options, .writer = writer}, Printer.print);
        _ = try writer.writeAll("]");
    }
    pub fn eql(self: *const Self, other: *const Self) bool {
        return self.table.eql(other.table, value.Value.eql);
    }
    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        self.table.deinit();
        allocator.destroy(self.table);
        allocator.destroy(self);
    }

};
