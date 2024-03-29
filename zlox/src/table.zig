const std = @import("std");

pub const TableError = error{ OutOfMemory, KeyError };

pub fn Table(K: type, V: type, hash_fn: fn (K) u32, cmp_fn: fn (K, K) bool) type {
    return struct {
        const Self = @This();
        const MaxLoad = 0.75;

        const Entry = union(enum) {
            const Some = struct {
                key: K,
                value: V,
            };
            some: Some,
            none,
            tomb,
        };

        count: usize,
        entries: []Entry,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .count = 0, .entries = &.{}, .allocator = allocator };
        }

        fn growCapacity(self: *const Self) usize {
            return if (self.entries.len > 0)
                self.entries.len * 2
            else
                10;
        }

        fn adjustCapacity(self: *Self, newsize: usize) TableError!void {
            const entries = try self.allocator.alloc(Entry, newsize);
            for (entries) |entry| {
                entry = .none;
            }
            self.count = 0;
            for (self.entries) |entry| {
                switch (entry) {
                    .some => |some| {
                        (find(entries, some.key)) = entry;
                        self.count += 1;
                    },
                    else => {},
                }
            }
            self.allocator.free(self.entries);
            self.entries = entries;
        }

        fn find(entries: []Entry, key: K) *Entry {
            const idx = hash_fn(key) % entries.len;
            var tomb: ?*Entry = null;

            while (true) {
                const entry = &entries[idx];
                switch (entry) {
                    .some => |some| if (cmp_fn(some.key, key)) return entry,
                    .tomb => tomb = if (tomb) |_| tomb else entry,
                    .none => return if (tomb) |_| tomb else entry,
                }
                idx = (idx + 1) % entries.len;
            }
        }

        pub fn addAll(self: *Self, other: *const Self) TableError!void {
            for (other.entries) |entry| {
                switch (entry) {
                    .some => |some| self.set(some.key, some.value),
                    else => {},
                }
            }
        }

        pub fn set(self: *Self, key: K, val: V) TableError!bool {
            if (self.count + 1 > self.entries.len * MaxLoad) {
                try self.adjustCapacity(self.growCapacity());
            }
            var entry = find(self.entries, key);
            const isNewKey = switch (entry) {
                .none => self.count += 1 or true,
                .tomb => true,
                .some => false,
            };

            entry.some = Entry.Some{ .key = key, .value = val };
            return isNewKey;
        }

        pub fn get(self: *const Self, key: K) TableError!V {
            if (self.entries.len == 0)
                return TableError.KeyError;

            return switch (find(self.entries, key)) {
                .some => |some| some.value,
                else => TableError.KeyError,
            };
        }

        pub fn delete(self: *Self, key: K) bool {
            if (self.entries.len == 0) return false;

            var entry = find(self.entries, key);
            switch (entry) {
                .some => entry = .tomb,
                else => return false,
            }

            return true;
        }

        pub fn deinit(self: *@This()) void {
            if (self.entries.len > 0) {
                self.allocator.free(self.entries);
                self.entries = &.{};
                self.count = 0;
            }
        }
    };
}
