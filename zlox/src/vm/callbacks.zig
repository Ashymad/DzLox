const std = @import("std");
const GC = @import("../gc.zig").GC;
const Obj = GC.Obj;
const Value = @import("../value.zig").Value;

const Number = Value.tagType(.number);
const Bool = Value.tagType(.bool);

pub const Error = Obj.Error;

pub fn Type(comptime in_tag: anytype, comptime out_tag: anytype) type {
    if (@TypeOf(in_tag) == Obj.Type) {
        return struct {
            objects: *GC,
            _call: *const fn (self: *const @This(), Value.tagType(in_tag), Value.tagType(in_tag)) Error!Value.tagType(out_tag),
            pub fn call(self: *const @This(), a: Value.tagType(in_tag), b: Value.tagType(in_tag)) Error!Value.tagType(out_tag) {
                return self._call(self, a, b);
            }
        };
    } else {
        return struct {
            call: fn (Value.tagType(in_tag), Value.tagType(in_tag)) callconv(.@"inline") Error!Value.tagType(out_tag),
        };
    }
}

pub fn concatenate(objects: *GC) Type(Obj.Type.String, Obj.Type.String) {
    const Ret = Type(Obj.Type.String, Obj.Type.String);
    const ret = Ret{ .objects = objects, ._call = struct {
        pub fn concatenate(self: *const Ret, lhs: *Obj, rhs: *Obj) Error!*Obj {
            return try self.objects.emplace_cast(.String, &.{ (lhs.cast(.String) catch unreachable).slice(), (rhs.cast(.String) catch unreachable).slice() });
        }
    }.concatenate };
    return ret;
}

pub const add = Type(Value.number, Value.number){ .call = struct {
    pub inline fn add(a: Number, b: Number) Error!Number {
        return a + b;
    }
}.add };
pub const mul = Type(Value.number, Value.number){ .call = struct {
    pub inline fn mul(a: Number, b: Number) Error!Number {
        return a * b;
    }
}.mul };
pub const sub = Type(Value.number, Value.number){ .call = struct {
    pub inline fn sub(a: Number, b: Number) Error!Number {
        return a - b;
    }
}.sub };
pub const div = Type(Value.number, Value.number){ .call = struct {
    pub inline fn div(a: Number, b: Number) Error!Number {
        return a / b;
    }
}.div };
pub const less = Type(Value.number, Value.bool){ .call = struct {
    pub inline fn less(a: Number, b: Number) Error!Bool {
        return a < b;
    }
}.less };
pub const more = Type(Value.number, Value.bool){ .call = struct {
    pub inline fn more(a: Number, b: Number) Error!Bool {
        return a > b;
    }
}.more };
