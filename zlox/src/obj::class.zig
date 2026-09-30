const std = @import("std");

const utils = @import("lib::utils.zig");
const table = @import("lib::table.zig");
const hash = @import("hash.zig");

const Packed = @import("lib::packed.zig").Packed;
const Obj = @import("obj.zig").Obj;
const Value = @import("value.zig").Value;
const GC = @import("gc.zig").GC;

pub fn Class(fields: anytype) type {
    const Super = Obj(fields);

    return packed struct {
        const Self = @This();

        pub const Arg = void;
        pub const Error = error{OutOfMemory};

        pub const Methods = table.Table(*Super.String, *Super.Function, hash.hash_t(*Super.String), Super.String.eql);

        obj: Super,
        methods: Packed(*Methods),

        pub fn init(_: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* = Self{
                .obj = Super.make(Self),
                .methods = try Packed(*Methods).create(allocator),
            };
            return self;
        }

        pub fn cast(self: anytype) utils.copy_const(@TypeOf(self), *Super) {
            return @ptrCast(self);
        }

        pub fn method(self: *Self, name: *Super.String) !union(enum) {
            Static: *Super.Function,
            Unbound: struct {
                this: usize,
                fun: *Super.Function,

                pub fn bind(sel: *const @This(), gc: *GC, this: *Super.Instance) !*Super.Function {
                    var fun = try gc.emplace(.Function, GC.name_of(sel.fun.cast()), .{
                        .chunk = sel.fun.chunk.ptr(),
                        .arity = sel.fun.arity,
                        .upvalues = @intCast(sel.fun.upvalues.len()),
                    });

                    fun.upvalues.set(sel.fun.upvalues.ptr());

                    var thi = Value.init(this.cast());

                    fun.upvalues.ptr()[sel.this] = try gc.emplace(.Upvalue, null, .{
                        .val = &thi,
                        .slot = 0,
                        .closed = true,
                    });

                    return fun;
                }
            },
        } {
            const met = try self.methods.ptr().get(name);

            for (met.upvalues.ptr(), 0..) |upvalue, idx| {
                if (upvalue == null) {
                    return .{ .Unbound = .{ .fun = met, .this = idx } };
                }
            }

            return .{ .Static = met };
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            self.methods.destroy(allocator);
            allocator.destroy(self);
        }
    };
}
