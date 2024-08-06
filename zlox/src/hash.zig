const Obj = @import("obj.zig").Obj;
const Value = @import("value.zig").Value;

pub fn hash_append_t(T: type) fn (u32, T) u32 {
    return switch (T) {
        []const u8, []u8 => struct {
            pub fn fun(old: u32, val: T) u32 {
                var ret = old;
                for (val) |char| {
                    ret = (ret ^ char) *% 16777619;
                }
                return ret;
            }
        }.fun,
        f64 => struct {
            pub fn fun(old: u32, val: T) u32 {
                const vali: *const u64 = @ptrCast(&val);
                const int = vali.* & 0xfffffffffffff000;
                const ptr: [*]const u8 = @ptrCast(&int);
                return hash_append_t([]const u8)(old, ptr[0..@sizeOf(T)]);
            }
        }.fun,
        bool => struct {
            pub fn fun(old: u32, val: T) u32 {
                return hash_append_t([]const u8)(old, if (val) "\xff" else "\x00");
            }
        }.fun,
        else => @compileError("hash_append_t(" ++ @typeName(T) ++ "): Unsupported type"),
    };
}

pub fn hash_append(ret: u32, val: anytype) u32 {
    return hash_append_t(@TypeOf(val))(ret, val);
}

pub fn hash_t(T: type) fn (T) u32 {
    return switch (T) {
        *Obj.Table, *const Obj.Table, *Obj.String, *const Obj.String => struct {
            pub fn fun(val: T) u32 {
                return val.hash;
            }
        }.fun,
        *Obj, *const Obj  => struct {
            pub fn fun(val: T) u32 {
                return switch (val.type) {
                    .String => hash_append_t([]const u8)(hash(val.cast(.String) catch unreachable), "\x01"),
                    .Table => hash_append_t([]const u8)(hash(val.cast(.Table) catch unreachable), "\x02"),
                };
            }
        }.fun,
        Value => struct {
            pub fn fun(val: T) u32 {
                return switch(val) {
                    .number => |v| hash_append_t([]const u8)(hash(v), "\x01"),
                    .char => |v| hash_t([]const u8)(&[_]u8{v, 2}),
                    .bool => |v| hash_append_t([]const u8)(hash(v), "\x03"),
                    .nil => hash_t([]const u8)("\x04"),
                    .obj => |v| hash_append_t([]const u8)(hash(v), "\x05"),
                };
            }
        }.fun,
        else => struct {
            pub fn fun(val: T) u32 {
                return hash_append_t(T)(2166136261, val);
            }
        }.fun,
    };
}

pub fn hash(val: anytype) u32 {
    return hash_t(@TypeOf(val))(val);
}
