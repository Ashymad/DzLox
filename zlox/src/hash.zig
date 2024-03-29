const Obj = @import("obj.zig").Obj;

pub fn hash_t(T: type) fn (T) u32 {
    return switch (T) {
        []const u8, [*]const u8, []u8, [*]u8 => struct {
            pub fn fun(key: T) u32 {
                var ret: u32 = 2166136261;
                for (key) |char| {
                    ret ^= char;
                    ret *= 16777619;
                }
                return ret;
            }
        }.fun,
        Obj, *Obj, *const Obj => struct {
            pub fn fun(key: T) u32 {
                return key.hash;
            }
        }.fun,
        else => @compileError("Unsupported type"),
    };
}

pub fn hash(val: anytype) u32 {
    return hash_t(@TypeOf(val))(val);
}
