const std = @import("std");

pub fn Array(comptime T: type, comptime S: type, comptime size: S) type {
    return struct {
        count: S,
        capacity: S,
        elements: []T,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return @This() {
                .count = 0,
                .capacity = size,
                .elements = try allocator.alloc(T, size),
                .allocator = allocator
            };
        }

        pub fn add(self: *@This(), val: T) !void {
            if (self.capacity < self.count + 1) {
                self.capacity = 2 * self.count;
                self.elements = try self.allocator.realloc(self.elements, self.capacity);
            }
            self.elements[self.count] = val;
            self.count += 1;
        }

        pub fn get(self: *const @This(), idx: S) !T {
            if (idx >= self.count) 
                return error.IndexOutOfBounds;
            return self.elements[idx];
        }

        pub fn last(self: *const @This()) !T {
            if (self.count == 0)
                return error.IndexOutOfBounds;
            return self.get(self.count - 1);
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.elements);
        }
    };
}

pub fn RLEArray(comptime T: type, comptime size: usize) type {
    return struct {
        array: Array(element, usize, size),

        const element = struct {val: T, run: usize};

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return @This() {
                .array = try Array(element, usize, size).init(allocator),
            };
        }

        pub fn add(self: *@This(), val: T) !void {
            const last = self.array.last() catch {
                try self.array.add(.{.val = val, .run = 1});
                return;
            };
            if (val == last.val) {
                self.array.elements[self.array.count-1].run += 1;
            } else {
                try self.array.add(.{.val = val, .run = 1});
            }
        }

        pub fn get(self: *const @This(), idx: usize) !T {
            var i: usize = 0;
            var sum: usize = 0;
            while(idx >= sum) : (i += 1) {
                sum += (try self.array.get(i)).run;
            }
            if (i > 0) return self.array.elements[i-1].val
            else return (try self.array.get(i)).val;
        }

        pub fn deinit(self: *@This()) void {
            self.array.deinit();
        }
    };
}
