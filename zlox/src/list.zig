const std = @import("std");
const utils = @import("comptime_utils.zig");

pub fn List(T: type) type {
    return struct {
        const Self = @This();

        pub const Error = error{ OutOfMemory, IndexOutOfBounds, Empty };

        const Element = struct {
            val: ?T,
            next: ?*@This(),
            prev: ?*@This(),
        };

        len: usize,
        tip: ?*Element,
        end: ?*Element,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .len = 0,
                .tip = null,
                .end = null,
                .allocator = allocator,
            };
        }

        pub fn eql(self: *const Self, other: *const Self, eql_fn: fn(T, T) bool) bool {
            if (self.len != other.len) return false;
            if (self.len == 0) return true;
            var tip1 = self.tip;
            var tip2 = other.tip;
            while (tip1) |el1| : (tip1 = el1.next) {
                if (el1.val) |val1| {
                    if (tip2.?.val) |val2| {
                        if (!eql_fn(val1, val2)) return false;
                    } else {
                        return false;
                    }
                } else if (tip2.?.val) |_| {
                    return false;
                }
                tip2 = tip2.?.next;
            }
            return true;
        }

        pub fn free(self: *Self) void {
            while (true) {_ = self.pop() catch return;}
        }

        pub fn get(self: *const Self, index: usize) Error!T {
            if (index >= self.len) {
                return Error.IndexOutOfBounds;
            }
            var idx_rev: usize = index;
            var idx = self.len - idx_rev;
            idx_rev += 1;

            if (idx < idx_rev) {
                var tip = self.tip;
                while(idx > 1) : (idx -= 1) {
                    tip = tip.?.next;
                }
                return tip.?.val orelse Error.IndexOutOfBounds;
            } else {
                var end = self.end;
                while(idx_rev > 1) : (idx_rev -= 1) {
                    end = end.?.prev;
                }
                return end.?.val orelse Error.IndexOutOfBounds;
            }
        }

        fn _set(self: *Self, index: usize, val: ?T) Error!bool {
            var idx_rev: isize = @intCast(index);
            var idx: isize = @as(isize, @intCast(self.len)) - idx_rev;
            idx_rev += 1;
            var isNewVal = false;

            if (idx <= 0) {
                while(idx < 0) : (idx += 1) {
                    try self._push(null);
                }
                try self._push(val);
                isNewVal = true;
            } else if (idx < idx_rev) {
                var tip = self.tip;
                while(idx > 1) : (idx -= 1) {
                    tip = tip.?.next;
                }
                tip.?.val = val;
            } else {
                var end = self.end;
                while(idx_rev > 1) : (idx_rev -= 1) {
                    end = end.?.prev;
                }
                end.?.val = val;
            }
            return isNewVal;
        }

        pub fn set(self: *Self, index: usize, val: T) Error!bool {
            return self._set(index, val);
        }

        pub fn delete(self: *Self, index: usize) void {
            if (index >= self.len) return;
            if (index == self.len - 1) {
                _ = self.pop() catch unreachable;
            } else {
                _ = self._set(index, null) catch unreachable;
            }
        }

        pub fn insert_before(self: *Self, element: ?*Element, val: T) Error!void {
            if(element) |el| {
                if(el.prev) |prev| {
                    const new = try self.allocator.create(Element);
                    new.* = .{.val = val, .next = el, .prev = prev};
                    prev.next = new;
                    el.prev = new;
                    self.len += 1;
                    return;
                }       
            } 
            try self.push(val);
        }

        pub fn insert_after(self: *Self, element: ?*Element, val: T) Error!void {
            if(element) |el| {
                if(el.next) |next| {
                    const new = try self.allocator.create(Element);
                    new.* = .{.val = val, .next = next, .prev = el};
                    next.prev = new;
                    el.next = new;
                    self.len += 1;
                    return;
                }       
            } 
            try self.push_end(val);
        }

        fn _pop(self: *Self) Error!?T {
            if (self.tip) |tip| {
                if (tip.next) |next| {
                    next.prev = null;
                    self.tip = next;
                } else {
                    self.tip = null;
                    self.end = null;
                }
                self.len -= 1;
                const val = tip.val;
                self.allocator.destroy(tip);
                return val;
            }
            return Error.Empty;
        }

        pub fn pop(self: *Self) Error!T {
            const val = try self._pop();
            while (self.tip) |tip| {
                if (tip.val) |_| break;
                _ = self._pop() catch unreachable;
            }
            return val.?;
        }

        fn _push(self: *Self, val: ?T) Error!void {
            const new_tip = try self.allocator.create(Element);
            if (self.end == null) {
                self.end = new_tip;
            }
            if (self.tip) |old_tip| {
                old_tip.prev = new_tip;
            }
            new_tip.* = Element{.val = val, .next = self.tip, .prev = null};
            self.tip = new_tip;
            self.len += 1;
        }

        pub fn push(self: *Self, val: T) Error!void {
            return self._push(val);
        }

        fn _push_end(self: *Self, val: ?T) Error!void {
            const new_end = try self.allocator.create(Element);
            if (self.tip == null) {
                self.tip = new_end;
            }
            if (self.end) |old_end| {
                old_end.next = new_end;
            }
            new_end.* = Element{.val = val, .prev = self.end, .next = null};
            self.end = new_end;
            self.len += 1;
        }

        pub fn push_end(self: *Self, val: T) Error!void {
            return self._push_end(val);
        }

        pub fn for_each(self: *const Self, arg: anytype, fun: fn (@TypeOf(arg), ?T) void) void {
            var end = self.end;
            while (end) |el| : (end = el.prev) {
                if (@TypeOf(arg) == void)
                    fun(el.val)
                else
                    fun(arg, el.val);
            }
        }

        pub fn for_each_try(self: *const Self, arg: anytype, fun: anytype) utils.fn_error(fun)!void {
            var end = self.end;
            while (end) |el| : (end = el.prev) {
                if (@TypeOf(arg) == void)
                    try fun(el.val)
                else
                    try fun(arg, el.val);
            }
        }
    };
}
