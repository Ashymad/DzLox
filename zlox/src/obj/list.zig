const std = @import("std");

const Value = @import("../value.zig").Value;
const utils = @import("../comptime_utils.zig");
const list_zig = @import("../list.zig");
const pack = @import("../packed.zig");

pub fn List(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();

        pub const List = list_zig.List(Value);
        pub const Arg = void;
        pub const Error = error { OutOfMemory, InvalidArgument } || Self.List.Error;

        obj: Super,
        list: pack.Packed(*Self.List),

        pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super.make(Self),
                .list = try pack.Packed(*Self.List).new(allocator)
            };
            self.list.ptr().* = Self.List.init(allocator);
            return self;
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) !void {
            const Printer = struct {
                writer: @TypeOf(writer),
                count: usize,

                pub fn print(this: *@This(), val: ?Value) std.Io.Writer.Error!void {
                    this.count -= 1;
                    if (val) |v| {
                        try v.format(this.writer);
                    } else {
                        _ = try this.writer.write("-");
                    }
                    if (this.count > 0) _ = try this.writer.write(", ");
                }

            };

            var printer = Printer{.writer = writer, .count = self.list.ptr().len};

            _ = try writer.write("[");
            try self.list.ptr().for_each_try(&printer, Printer.print);
            _ = try writer.writeAll("]");
        }

        pub fn eql(self: *const Self, other: *const Self) bool {
            return self.list.ptr().eql(other.list.ptr(), Value.eql);
        }

        pub fn free(self: *Self, allocator: std.mem.Allocator) void {
            self.list.ptr().free();
            self.list.free(allocator);
            allocator.destroy(self);
        }

        pub fn delete(self: *Self, index: Value) void {
            var list = self.list.ptr();
            if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(list.len)) or index.number < 0) {
                return;
            }
            list.delete(@intFromFloat(index.number));
        }

        pub fn get(self: *const Self, index: Value) Error!Value {
            var list = self.list.ptr();
            if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(list.len)) or index.number < 0) {
                return Error.InvalidArgument;
            }
            return list.get(@intFromFloat(index.number));
        }

        pub fn set(self: *Self, index: Value, val: Value) Error!void {
            if (!index.is(Value.number) or index.number < 0) {
                return Error.InvalidArgument;
            }
            _ = try self.list.ptr().set(@intFromFloat(index.number), val);
        }
    };
}
