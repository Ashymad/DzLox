const std = @import("std");
const table = @import("../table.zig");
const hash = @import("../hash.zig");
const Value = @import("../value.zig").Value;
const utils = @import("../comptime_utils.zig");

pub fn Table(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();
        pub const Arg = void;
        const Table = table.Table(Value, Value, hash.hash_t(Value), Value.eql);
        pub const Error = error { OutOfMemory } || Self.Table.Error;

        obj: Super,
        table: *Self.Table,
        len: usize,

        pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .table = try allocator.create(Self.Table),
                .len = 0,
            };
            self.table.* = Self.Table.init(allocator);
            return self;
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn set(self: *Self, key: Value, val: Value) Error!bool {
            self.len += 1;
            return self.table.set(key, val);
        }

        pub fn get(self: *Self, key: Value) Error!Value {
            return self.table.get(key);
        }

        pub fn delete(self: *Self, key: Value) void {
            if (self.table.delete(key)) self.len -= 1;
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            const Printer = struct {
                writer: @TypeOf(writer),
                count: usize,

                pub fn print(this: *@This(), key: Value, val: Value) std.Io.Writer.Error!void {
                    this.count -= 1;

                    try key.format(this.writer);
                    _ = try this.writer.write(":");
                    try val.format(this.writer);
                    if (this.count > 0) _ = try this.writer.write(", ");
                }

            };

            var printer = Printer{.writer = writer, .count = self.len};
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
}
