const std = @import("std");

fn is_type(T: type, comptime name: []const u8) bool {
    return @as(std.meta.Tag(std.builtin.Type), @typeInfo(T)) == @field(std.meta.Tag(std.builtin.Type), name);
}

pub fn Packed(T: type) type {
    comptime var _Type = T;
    comptime var _Ptr =T;

    const _optional = is_type(_Type, "optional");
    if (_optional) {
        _Type = @typeInfo(_Type).optional.child;
    }

    const _pointer = is_type(_Type, "pointer");
    if (_pointer) {
        _Ptr = _Type;
        _Type = @typeInfo(_Type).pointer.child;
    } else {
        @compileError("Expected pointer type, got " ++ @typeName(_Type));
    }

    return packed struct {
        const pointer = _pointer;
        const optional = _optional;
        const Type = _Type;
        const Ptr = _Ptr;

        const Self = @This();

        _ptr: usize,

        pub fn new(allocator: std.mem.Allocator) !Self {
            return Self.init(try allocator.create(Type));
        }

        pub fn init(arg: Ptr) Self {
            return Self{
                ._ptr = @intFromPtr(arg),
            };
        }

        pub fn nil() Self {
            if (!optional) {
                @compileError("Cannot create nil for non-optional type");
            }

            return Self{
                ._ptr = 0,
            };
        }

        pub fn valid(self: Self) bool {
            return !optional or self._ptr != 0;
        }

        pub fn ptr(self: Self) Ptr {
            if (self.valid()) {
                return @ptrFromInt(self._ptr);
            } else {
                @panic("Attempt to access null pointer");
            }
        }

        pub fn free(self: Self, allocator: std.mem.Allocator) void {
            allocator.destroy(self.ptr());
        }
    };
}
