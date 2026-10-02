const std = @import("std");
const utils = @import("lib::utils.zig");

const Flag = struct {
    flag: u64,
    mask: u64,
    true: bool = true,
    shift: u6 = 0,

    pub fn check(self: *const @This(), val: u64) bool {
        return self.true == ((val & self.mask) == self.flag);
    }

    pub fn decode(self: *const @This(), val: u64) u64 {
        return if (self.true) (val & ~self.mask) << self.shift else val;
    }

    pub fn encode(self: *const @This(), val: u64) u64 {
        return if (self.true) ((val >> self.shift) & ~self.mask) | self.flag else val;
    }
};

pub fn Packer(comptime MAX: u6) type {
    const MAXU64: u64 = std.math.maxInt(u64);
    const MASK: u64 = ~(MAXU64 << MAX);

    return struct {
        matrix: [MAX]?u64,

        pub fn init() @This() {
            return .{ .matrix = @splat(0) };
        }

        fn mask(idx: u6) u64 {
            return MASK & (MAXU64 << idx);
        }

        fn inc(val: u64, idx: u6) ?u64 {
            return if ((val & mask(idx)) == mask(idx))
                null
            else
                val + (@as(u64, 1) << idx);
        }

        pub fn next(self: *@This(), idx: u6) ?u64 {
            if (self.matrix[idx]) |ret| {
                var i: u6 = idx;
                while (i < MAX) : (i += 1) {
                    if (self.matrix[i]) |val| {
                        if (val == (ret & mask(i)))
                            self.matrix[i] = inc(val, i)
                        else
                            break;
                    } else break;
                }

                i = idx;
                while (i > 0) {
                    i -= 1;
                    if (self.matrix[i]) |val| {
                        if (val == (ret & mask(i)))
                            self.matrix[i] = self.matrix[idx]
                        else
                            break;
                    } else @panic("The Matrix has been breached!");
                }

                return ret;
            }
            return null;
        }
    };
}

pub fn NaNBox(comptime fields: anytype) type {
    const Fields = @TypeOf(fields);

    if (!utils.is_type(Fields, "struct"))
        @compileError("The fields have to be a struct of types");

    const flags = blk: {
        const info = @typeInfo(Fields).@"struct";

        var flags: [info.field_names.len]Flag = undefined;

        var float = false;

        const QNAN: u64 = 0x7ffc000000000000;
        const SIGN: u64 = 0x8000000000000000;

        const Pack = Packer(51);
        var packer = Pack.init();

        inline for (info.field_names, info.field_types, &flags) |name, ftype, *flag| {
            if (ftype != type)
                @compileError("The fields have to be types, but field " ++ name ++ " is " ++ @typeName(ftype));

            const field = @field(fields, name);
            const is_ptr = utils.is_type(field, "pointer");

            if (field == f64) {
                if (float)
                    @compileError("There can only be one f64 field");

                flag.* = .{ .flag = QNAN, .mask = QNAN, .true = false };
                float = true;
            } else if (is_ptr or @bitSizeOf(field) < 51) {
                const bitsz: u6 = if (is_ptr) 45 else @bitSizeOf(field);

                if (packer.next(bitsz)) |pack| {
                    flag.* = Flag{
                        .flag = (SIGN & (pack << 13)) | QNAN | pack,
                        .mask = SIGN | QNAN | Pack.mask(bitsz),
                        .shift = if (is_ptr) 3 else 0,
                    };
                } else {
                    @compileError("Too many fields to fit");
                }
            } else {
                @compileError("The field " ++ name ++ " has more than 50 bits");
            }
        }

        if (!float)
            @compileError("At least one f64 field is required");

        break :blk flags;
    };

    return struct {
        const Self = @This();

        pub const Type = utils.enumFromStruct(Fields, usize);
        pub const Error = error{WrongTag};

        value: u64,

        pub fn flag(comptime tag: Type) Flag {
            return flags[@backingInt(tag)];
        }

        pub fn typeof(comptime tag: Type) type {
            return @field(fields, @tagName(tag));
        }

        pub fn of(comptime tag: Type, val: typeof(tag)) Self {
            return Self{
                .value = flag(tag).encode(utils.typepun(u64, val)),
            };
        }

        pub fn to(self: *const Self, comptime tag: Type) !typeof(tag) {
            return if (self.is(tag))
                utils.typepun(typeof(tag), flag(tag).decode(self.value))
            else
                Error.WrongTag;
        }

        pub fn is(self: *const Self, comptime tag: Type) bool {
            return flag(tag).check(self.value);
        }
    };
}
