const std = @import("std");

pub fn TrieTable(comptime T: type) type {
    return struct {
        value: ?T,
        data: [26]?*@This(),
        allocator: ?std.heap.ArenaAllocator,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return @This(){ .value = null, .data = [_]?*@This(){null} ** 26, .allocator = std.heap.ArenaAllocator.init(allocator) };
        }

        pub fn put(self: *@This(), word: []const u8, value: T) !void {
            var this = self;
            const allo = self.allocator.?.allocator();
            for (word) |ch| {
                const idx = ch - 'a';
                if (this.data[idx]) |val| {
                    this = val;
                } else {
                    var new = try allo.create(@This());
                    new.value = null;
                    new.data = [_]?*@This(){null} ** 26;
                    new.allocator = null;
                    this.data[idx] = new;
                    this = new;
                }
            }
            this.value = value;
        }

        pub fn get(self: *const @This(), word: []const u8) ?T {
            var this = self;
            for (word) |ch| {
                if (ch < 'a' or ch > 'z') return null;
                const idx = ch - 'a';
                if (this.data[idx]) |val| {
                    this = val;
                } else {
                    return null;
                }
            }
            return this.value;
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.?.deinit();
        }
    };
}
