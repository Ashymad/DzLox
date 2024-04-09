const Obj = @import("obj.zig").Obj;

pub fn hash_append_t(T: type) fn (u32, T) u32 {
    return switch (T) {
        []const u8, [*]const u8, []u8, [*]u8 => struct {
            pub fn fun(old: u32, val: T) u32 {
                var ret = old;
                for (val) |char| {
                    ret ^= char;
                    ret *%= 16777619;
                }
                return ret;
            }
        }.fun,
        else => @compileError("Unsupported type"),
    };
}

pub fn hash_append(ret: u32, val: anytype) u32 {
    return hash_append_t(@TypeOf(val))(ret, val);
}

pub fn hash_t(T: type) fn (T) u32 {
    return switch (T) {
        []const u8, [*]const u8, []u8, [*]u8 => struct {
            pub fn fun(val: T) u32 {
                return hash_append_t(T)(2166136261, val);
            }
        }.fun,
        Obj.String, *Obj.String, *const Obj.String => struct {
            pub fn fun(val: T) u32 {
                return val.hash;
            }
        }.fun,
        else => @compileError("Unsupported type"),
    };
}

pub fn hash(val: anytype) u32 {
    return hash_t(@TypeOf(val))(val);
}
