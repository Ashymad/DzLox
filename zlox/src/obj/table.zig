const std = @import("std");
const table = @import("../table.zig");
const hash = @import("../hash.zig");
const Value = @import("../value.zig").Value;
const utils = @import("../comptime_utils.zig");

const Super = @import("../obj.zig").Obj;

pub const Table = packed struct {
    const Self = @This();
    pub const Arg = void;
    const Table = table.Table(Value, Value, hash.hash_t(Value), Value.eql);
    pub const Error = error { OutOfMemory } || Self.Table.Error;

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

    pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
        return @ptrCast(self);
    }

    pub fn set(self: *Self, key: Value, val: Value) Error!bool {
        self.hash +%= hash.hash(key) +% hash.hash(val);
        return self.table.set(key, val);
    }

    pub fn get(self: *Self, key: Value) Error!Value {
        return self.table.get(key);
    }

    pub fn delete(self: *Self, key: Value) void {
        const val = self.table.get(key) catch return;
        self.hash -%= hash.hash(key) -% hash.hash(val);
        _ = self.table.delete(key);
    }

    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const Printer = struct {
            options: std.fmt.FormatOptions,
            writer: @TypeOf(writer),
            count: usize,

            pub fn print(this: *@This(), key: Value, val: Value) utils.fn_error(@TypeOf(writer).write)!void {
                this.count -= 1;

                try key.format(fmt, this.options, this.writer);
                _ = try this.writer.write(":");
                try val.format(fmt, this.options, this.writer);
                if (this.count > 0) _ = try this.writer.write(", ");
            }

        };

        var printer = Printer{.options = options, .writer = writer, .count = self.table.count};
        _ = try writer.write("[");
        if (self.table.count > 0) {
            try self.table.for_each_try(&printer, Printer.print);
        } else {
            _ = try writer.write(":");
        }
        _ = try writer.writeAll("]");
    }

    pub fn eql(self: *const Self, other: *const Self) bool {
        return self.table.eql(other.table, Value.eql);
    }

    pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
        self.table.deinit();
        allocator.destroy(self.table);
        allocator.destroy(self);
    }
};
