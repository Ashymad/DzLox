const std = @import("std");

pub fn RLEArray(comptime T: type) type {
    return struct {
        count: usize,
        capacity: usize,
        elements: []element,
        allocator: std.mem.Allocator,

        const element = struct {val: T, run: usize};

        pub fn init(allocator: std.mem.Allocator) !@This() {
            const cap = 8;
            return @This() {
                .count = 0,
                .capacity = cap,
                .elements = try allocator.alloc(element, cap),
                .allocator = allocator
            };
        }

        pub fn add(self: *@This(), val: T) !void {
            if (self.capacity < self.count + 1) {
                self.capacity = 2 * self.count;
                self.elements = try self.allocator.realloc(self.elements, self.capacity);
            }
            if (val == self.elements[self.count].val) {
                self.elements[self.count].run += 1;
            } else {
                self.elements[self.count] = .{.val = val, .run = 0};
                self.count += 1;
            }
        }

        pub fn get(self: *const @This(), idx: usize) T {
            var i: usize = 0;
            var sum: usize = 0;
            while(idx > sum) : (i += 1) {
                sum += self.elements[i].run;
            }
            return self.elements[i].val;
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.elements);
        }
    };
}
