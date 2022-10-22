const std = @import("std");

pub const OP = enum(u8) { RETURN };

fn grow_capacity(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

fn grow_array(comptime T: type, allocator: std.mem.Allocator, ptr: ?[]T, new_count: usize) ![]T {
    return if (ptr == null)
        try allocator.alloc(T, new_count)
    else
        try allocator.reallocAtLeast(ptr.?, new_count);
}

pub const Chunk = struct {
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{ .count = 0, .capacity = 0, .code = null, .allocator = allocator };
    }
    pub fn write(self: *Chunk, byte: u8) !void {
        if (self.capacity < self.count + 1) {
            self.capacity = grow_capacity(self.capacity);
            self.code = try grow_array(u8, self.allocator, self.code, self.capacity);
        }
        self.code.?[self.count] = byte;
        self.count += 1;
    }
    pub fn free(self: *Chunk) void {
        self.allocator.free(self.code.?);
    }
    count: usize,
    capacity: usize,
    code: ?[]u8,
    allocator: std.mem.Allocator,
};
