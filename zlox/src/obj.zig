const std = @import("std");

pub const Obj = packed struct {
    const Self = @This();

    pub const String = struct {
        obj: Self,
        len: usize,
        fn data(self: *@This()) [*]u8 {
            const ptr: [*]u8 = @ptrCast(self);
            return ptr + @sizeOf(@This());
        }
        fn cdata(self: *const @This()) [*]const u8 {
            const ptr: [*]const u8 = @ptrCast(self);
            return ptr + @sizeOf(@This());
        }
        fn new(len: usize, allocator: std.mem.Allocator) !*@This() {
            const ret: *@This() = @ptrCast(try allocator.alignedAlloc(u8, @alignOf(@This()), @sizeOf(@This()) + len));
            ret.* = @This(){ .obj = Self{
                .type = Self.Type.String,
            }, .len = len };
            return ret;
        }
        pub fn slice(self: *const @This()) []const u8 {
            return self.cdata()[0..self.len];
        }
        pub fn init(string: []const u8, allocator: std.mem.Allocator) !*@This() {
            const ret = try new(string.len, allocator);
            @memcpy(ret.data(), string);
            return ret;
        }
        pub fn cat(self: *const @This(), other: *const @This(), allocator: std.mem.Allocator) !*@This() {
            const ret = try new(self.len + other.len, allocator);
            @memcpy(ret.data(), self.slice());
            @memcpy(ret.data() + self.len, other.slice());
            return ret;
        }
        pub fn cast(self: *@This()) *Self {
            return @ptrCast(self);
        }
    };

    pub const Type = enum {
        String,

        pub fn get(comptime self: @This()) type {
            return @field(Obj, @tagName(self));
        }
    };

    const Error = error{IllegalCastError};
    type: Type,

    pub fn is(self: *const Self, tp: Type) bool {
        return self.type == tp;
    }

    pub fn print(self: *const Self) void {
        switch (self.type) {
            .String => std.debug.print("\"{s}\"", .{self._cast(.String).slice()}),
        }
    }

    pub fn equal(self: *const Self, other: *const Self) bool {
        if (!self.is(other.type)) return false;
        return switch (self.type) {
            .String => std.mem.eql(u8, self._cast(.String).slice(), other._cast(.String).slice()),
        };
    }

    fn _cast(self: *const Self, comptime tp: Type) *const tp.get() {
        return @ptrCast(@alignCast(self));
    }

    pub fn cast(self: *const Self, comptime tp: Type) Error!*const tp.get() {
        if (!self.is(tp)) return Error.IllegalCastError;
        return self._cast(tp);
    }
};
