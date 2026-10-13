const std = @import("std");
const iterator = @import("lib::iterator.zig");

pub fn Array(comptime T: type) type {
    return struct {
        const Self = @This();
        const Init = 8;

        len: usize,
        data: []T,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .len = 0,
                .data = try allocator.alloc(T, Init),
                .allocator = allocator,
            };
        }

        pub fn iter(self: *Self) iterator.Slice(@TypeOf(Self.data)) {
            return iterator.slice(self.data[0..self.len]);
        }

        pub fn add(self: *Self, val: T) !void {
            if (self.data.len <= self.len) {
                self.data = try self.allocator.realloc(self.data, 2 * self.data.len);
            }
            self.data[self.len] = val;
            self.len += 1;
        }

        pub fn slice(self: *const Self) []const T {
            return self.data[0..self.len];
        }

        pub fn get(self: *const Self, idx: usize) ?T {
            return if (idx >= self.len) null else self.data[idx];
        }

        pub fn set(self: *const Self, idx: usize, val: T) !void {
            if (idx >= self.len)
                return error.IndexOutOfBounds;
            self.data[idx] = val;
        }

        pub fn last(self: *const Self) ?T {
            return if (self.len == 0) null else self.data[self.len - 1];
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }
    };
}
