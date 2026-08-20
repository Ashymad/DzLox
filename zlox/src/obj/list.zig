const std = @import("std");

const Value = @import("../value.zig").Value;
const utils = @import("../comptime_utils.zig");
const list_zig = @import("../list.zig");
const Packed = @import("../packed.zig").Packed;

pub fn List(fields: anytype) type {
    const Super = @import("../obj.zig").Obj(fields);

    return packed struct {
        const Self = @This();

        pub const List = list_zig.List(Value);
        pub const Arg = void;
        pub const Error = error{ OutOfMemory, InvalidArgument } || Self.List.Error;

        obj: Super,
        list: Packed(*Self.List),

        pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* = Self{
                .obj = Super.make(Self),
                .list = try Packed(*Self.List).create(allocator),
            };
            self.list.set(Self.List.init(allocator));
            return self;
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn format(self: *const Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            var iter = self.list.ptr().iter();
            var count = self.list.ptr().len();

            _ = try writer.write("[");
            while (iter.next()) |val| {
                count -= 1;
                try val.format(writer);
                if (count > 0) _ = try writer.write(", ");
            }
            _ = try writer.writeAll("]");
        }

        pub fn eql(self: *const Self, other: *const Self) bool {
            return self.list.ptr().eql(other.list.ptr(), Value.eql);
        }

        pub fn free(self: *Self, allocator: std.mem.Allocator) void {
            self.list.ptr().free();
            self.list.destroy(allocator);
            allocator.destroy(self);
        }

        pub fn delete(self: *Self, index: Value) void {
            var list = self.list.ptr();
            if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(list.len()))) {
                return;
            }
            _ = list.pop(@intFromFloat(index.number)) catch return;
        }

        pub fn get(self: *const Self, index: Value) Error!Value {
            var list = self.list.ptr();
            if (!index.is(Value.number) or index.number >= @as(Value.tagType(Value.number), @floatFromInt(list.len()))) {
                return Error.InvalidArgument;
            }
            return list.get(@intFromFloat(index.number));
        }

        pub fn set(self: *Self, index: Value, val: Value) Error!void {
            if (!index.is(Value.number)) {
                return Error.InvalidArgument;
            }
            _ = self.list.ptr().set(@intFromFloat(index.number), val) catch
                try self.list.ptr().push(@intFromFloat(index.number), val);
        }
    };
}
