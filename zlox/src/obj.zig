const std = @import("std");
const utils = @import("comptime_utils.zig");
const hash = @import("hash.zig");
const table = @import("table.zig");
const value = @import("value.zig");

pub const Obj = packed struct {
    const Super = @This();
    pub const Error = table.TableError || error{ OutOfMemory, IllegalCastError, NotFound };

    type: Type,

    pub const List = struct {
        const Self = @This();
        const Element = struct {
            obj: *Super,
            next: ?*@This(),
        };

        tip: ?*Element,
        allocator: std.mem.Allocator,
        map: String.Table,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .tip = null, .allocator = allocator, .map = String.Table.init(allocator) };
        }

        pub fn push(self: *Self, val: *Super) Error!void {
            var new_tip = try self.allocator.create(Element);
            new_tip.next = self.tip;
            new_tip.obj = val;
            self.tip = new_tip;
        }

        pub fn emplace(self: *Self, comptime tp: Type, arg: tp.get().Arg) Error!*Super {
            var newObj = true;
            const obj = switch (tp) {
                .String => (try String.intern(arg, &self.map, &newObj, self.allocator)).cast(),
                else => try Super.init(tp, arg, self.allocator),
            };
            if (newObj) try self.push(obj);
            return obj;
        }

        pub fn pop(self: *Self) ?*Element {
            if (self.tip) |tip| {
                self.tip = tip.next;
                tip.obj.free(self.allocator);
                return tip;
            }
            return null;
        }

        pub fn deinit(self: *Self) void {
            while (self.pop()) |tip| {
                self.allocator.destroy(tip);
            }
            self.map.deinit();
        }
    };

    pub const String = packed struct {
        const Self = @This();
        pub const Table = table.Table(*Self, void, hash.hash_t(*const Self), Self.eql);
        pub const Arg = []const []const u8;

        obj: Super,
        len: usize = 0,
        hash: u32,

        fn data(self: anytype) utils.copy_const(@TypeOf(self), [*]u8) {
            const p: utils.copy_const(@TypeOf(self), [*]u8) = @ptrCast(self);
            return p + @sizeOf(Self);
        }
        fn new(arg: Arg, params: ArgParams, allocator: std.mem.Allocator) Error!*Self {
            const ret: *Self = @ptrCast(try allocator.alignedAlloc(u8, @alignOf(Self), @sizeOf(Self) + params.len));
            ret.* = Self{
                .obj = Super{
                    .type = Super.Type.String,
                },
                .hash = params.hash,
            };
            for (arg) |el| {
                @memcpy(ret.data() + ret.len, el);
                ret.len += el.len;
            }
            return ret;
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.data()[0..self.len];
        }
        pub fn cast(self: *Self) *Super {
            return @ptrCast(self);
        }
        pub fn print(self: *const Self) void {
            std.debug.print("\"{s}\"", .{self.slice()});
        }
        pub fn eql(self: *const Self, other: *const Self) bool {
            return @intFromPtr(self) == @intFromPtr(other);
        }

        const ArgParams = struct { len: usize, hash: u32 };

        fn map_check(m_arg: Arg, m_params: ArgParams) struct {
            arg: Arg,
            params: ArgParams,
            pub fn check(self: *const @This(), k2: *const Self) bool {
                if (k2.hash == self.params.hash and k2.len == self.params.len) {
                    var idx: usize = 0;
                    for (self.arg) |el| {
                        if (!std.mem.eql(u8, k2.data()[idx .. idx + el.len], el))
                            return false;
                        idx += el.len;
                    }
                    return true;
                }
                return false;
            }
        } {
            return @TypeOf(map_check(m_arg, m_params)){ .arg = m_arg, .params = m_params };
        }

        fn arg_params(arg: Arg) ArgParams {
            var ret = ArgParams{ .len = 0, .hash = hash.hash_t([]const u8)(&.{}) };

            for (arg) |el| {
                ret.len += el.len;
                ret.hash = hash.hash_append(ret.hash, el);
            }
            return ret;
        }

        pub fn intern(arg: Arg, map: *Table, isNewKey: *bool, allocator: std.mem.Allocator) Error!*Self {
            const params = arg_params(arg);

            try map.checkCapacity();
            const entry = Table.find_(map.entries, params.hash, map_check(arg, params));
            isNewKey.* = entry.* != Table.Entry.some;
            if (isNewKey.*) {
                _ = map.set_(entry, try new(arg, params, allocator), {});
            }
            return entry.some.key;
        }

        pub fn init(_: Arg, _: std.mem.Allocator) Error!*Self {
            @compileError("The String Obj has to be interned");
        }

        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            const p: [*]align(@alignOf(Self)) const u8 = @ptrCast(self);
            allocator.free(p[0 .. @sizeOf(Self) + self.len]);
        }
    };

    pub const Map = packed struct {
        const Self = @This();
        pub const Arg = value.ValueArray;
        const Table = table.Table(value.Value, value.Value, hash.hash_t(value.Value), value.Value.eql);

        obj: Super,
        map: *Table,
        hash: u32,

        pub fn init(arg: Arg, allocator: std.mem.Allocator) Error!*Self {
            const self: *Self = try allocator.create(Self);
            self.* =  Self{
                .obj = Super{
                    .type = Super.Type.Map,
                },
                .map = try allocator.create(Table),
                .hash = 0,
            };
            self.map.* = Table.init(allocator);
            var i: u8 = 0;
            while (i < arg.len) : (i += 2) {
                const key = arg.get(i) catch unreachable;
                const val = arg.get(i+1) catch unreachable;
                self.hash +%= hash.hash(key) +% hash.hash(val);
                if (!try self.map.set(key, val)) {
                    return error.KeyError;
                }
            }
            return self;
        }
        pub fn cast(self: *Self) *Super {
            return @ptrCast(self);
        }

        pub fn set(self: *Self, key: value.Value, val: value.Value) !void {
            self.hash +%= hash.hash(key) +% hash.hash(val);
            _ = try self.map.set(key, val);
        }

        fn print_element(key: value.Value, val: value.Value) void {
            key.print();
            std.debug.print(":", .{});
            val.print();
            std.debug.print(",", .{});

        }
        pub fn print(self: *const Self) void {
            std.debug.print("[", .{});
            self.map.for_each(Self.print_element);
            std.debug.print("]", .{});
        }
        pub fn eql(self: *const Self, other: *const Self) bool {
            return self.map.eql(other.map, value.Value.eql);
        }
        pub fn free(self: *const Self, allocator: std.mem.Allocator) void {
            self.map.deinit();
            allocator.destroy(self.map);
            allocator.destroy(self);
        }

    };

    pub const Type = enum(u8) {
        String,
        Map,

        pub fn get(comptime self: @This()) type {
            return @field(Super, @tagName(self));
        }
    };

    pub fn init(comptime tp: Type, arg: tp.get().Arg, allocator: std.mem.Allocator) !*Super {
        return (try tp.get().init(arg, allocator)).cast();
    }
    pub fn print(self: *const Super) void {
        switch (self.type) {
            inline else => |tp| self._cast(tp).print(),
        }
    }
    pub fn eql(self: *const Super, other: *const Super) bool {
        if (!self.is(other.type)) return false;
        return switch (self.type) {
            inline else => |tp| self._cast(tp).eql(other._cast(tp)),
        };
    }
    pub fn free(obj: *Super, allocator: std.mem.Allocator) void {
        return switch (obj.type) {
            inline else => |tp| obj._cast(tp).free(allocator),
        };
    }

    pub fn is(self: *const Super, tp: Type) bool {
        return self.type == tp;
    }

    pub fn cast(self: anytype, comptime tp: Type) Error!utils.copy_const(@TypeOf(self), *tp.get()) {
        if (!self.is(tp)) return Error.IllegalCastError;
        return self._cast(tp);
    }

    fn _cast(self: anytype, comptime tp: Type) utils.copy_const(@TypeOf(self), *tp.get()) {
        return @ptrCast(@alignCast(self));
    }
};
