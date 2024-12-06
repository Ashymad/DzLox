const std = @import("std");

const Value = @import("../value.zig").Value;
const utils = @import("../comptime_utils.zig");
const list = @import("../list.zig");

pub fn List(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();

        pub const List = list.List(Value);
        pub const Arg = void;
        pub const Error = error { OutOfMemory, InvalidArgument } || Self.List.Error;

        obj: Super,
        list: *Self.List,

        pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .list = try allocator.create(Self.List)
            };
            self.list.* = Self.List.init(allocator);
            return self;
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) utils.fn_error(@TypeOf(writer).write)!void {
            const Printer = struct {
                options: std.fmt.FormatOptions,
                writer: @TypeOf(writer),
                count: usize,

                pub fn print(this: *@This(), val: ?Value) utils.fn_error(@TypeOf(writer).write)!void {
                    this.count -= 1;
                    if (val) |v| {
                        try v.format(fmt, this.options, this.writer);
                    } else {
                        _ = try this.writer.write("-");
                    }
                    if (this.count > 0) _ = try this.writer.write(", ");
                }

            };

            var printer = Printer{.options = options, .writer = writer, .count = self.list.len};

            _ = try writer.write("[");
            try self.list.for_each_try(&printer, Printer.print);
            _ = try writer.writeAll("]");
        }

        pub fn eql(self: *const Self, other: *const Self) bool {
            return self.list.eql(other.list, Value.eql);
        }

        pub fn free(self: *Self, allocator: std.mem.Allocator) void {
            self.list.free();
            allocator.destroy(self.list);
            allocator.destroy(self);
        }

        pub fn delete(self: *Self, index: Value) void {
            if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(self.list.len)) or index.number < 0) {
                return;
            }
            self.list.delete(@intFromFloat(index.number));
        }

        pub fn get(self: *const Self, index: Value) Error!Value {
            if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(self.list.len)) or index.number < 0) {
                return Error.InvalidArgument;
            }
            return self.list.get(@intFromFloat(index.number));
        }

        pub fn set(self: *Self, index: Value, val: Value) Error!void {
            if (!index.is(Value.number) or index.number < 0) {
                return Error.InvalidArgument;
            }
            _ = try self.list.set(@intFromFloat(index.number), val);
        }
    };
}
