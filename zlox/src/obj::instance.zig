const std = @import("std");

const utils = @import("lib::utils.zig");
const table = @import("lib::table.zig");
const hash = @import("hash.zig");

const Packed = @import("lib::packed.zig").Packed;
const Value = @import("value.zig").Value;
const Obj = @import("obj.zig").Obj;
const GC = @import("gc.zig").GC;

pub fn Instance(fields: anytype) type {
    const Super = Obj(fields);

    return packed struct {
        const Self = @This();

        pub const Arg = *Super.Class;
        pub const Error = error{OutOfMemory};

        pub const Fields = table.Table(*Super.String, Value, hash.hash_t(*Super.String), Super.String.eql);

        obj: Super,
        cls: Packed(*Super.Class),
        fields: Packed(*Fields),
        bound: Packed(*Super.Class.Methods),

        pub fn init(cls: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* = Self{
                .obj = Super.make(Self),
                .cls = Packed(*Super.Class).init(cls),
                .fields = try Packed(*Self.Fields).create(allocator),
                .bound = try Packed(*Super.Class.Methods).create(allocator),
            };
            return self;
        }

        pub fn method(self: *Self, gc: *GC, name: *Super.String) !*Super.Function {
            return self.bound.ptr().get(name) catch
                switch (try self.cls.ptr().method(name)) {
                    .Static => |sta| sta,
                    .Unbound => |unb| try self.bound.ptr().retset(name, try unb.bind(gc, self)),
                };
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn eql(_: *const Self, _: *const Self) bool {
            return false;
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            self.fields.destroy(allocator);
            self.bound.destroy(allocator);
            allocator.destroy(self);
        }
    };
}
