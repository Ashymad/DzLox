const std = @import("std");
const utils = @import("lib::utils.zig");

pub fn pun(Ret: type, val: anytype) Ret {
    if (@alignOf(@TypeOf(val)) < @alignOf(Ret)) {
        var ret: Ret = undefined;
        @as(*@TypeOf(val), @ptrCast(&ret)).* = val;
        return ret;
    } else {
        return @as(*const Ret, @ptrCast(&val)).*;
    }
}

fn expand(tag: u64) u64 {
    return ((0b100 & tag) << 61) | ((0b11 & tag) << 48);
}

pub fn NaNBox(comptime fields: anytype) type {
    const Fields = @TypeOf(fields);

    if (!utils.is_type(Fields, "struct"))
        @compileError("The fields have to be a struct of types");

    const info = @typeInfo(Fields).@"struct";
    const enum_f64 = 0xcafe;

    const enums, const HAS_PTR = blk: {
        var enums: [info.field_names.len]u64 = undefined;
        var floated = false;

        var e_val: u64 = 0;
        var e_ptr: u64 = 0;

        inline for (info.field_names, info.field_types, &enums) |nam, typ, *enm| {
            if (typ != type)
                @compileError("The fields have to be types, but field " ++ nam ++ " is " ++ @typeName(typ));

            const field = @field(fields, nam);
            const bitsz = @bitSizeOf(field);

            if (field == f64) {
                if (floated)
                    @compileError("There can only be one f64 field");
                enm.* = enum_f64;
                floated = true;
            } else if (utils.is_type(field, "pointer")) {
                if (e_ptr == 0 and e_val == 8)
                    @compileError("This NaNBox already has 8 non-pointer types");
                if (e_ptr == 8)
                    @compileError("This NaNBox already has 8 pointer types");
                enm.* = expand(0b111) | e_ptr;
                e_ptr += 1;
            } else if (bitsz < 48) {
                if (e_val == 8)
                    @compileError("This NaNBox already has 8 non-pointer types");
                if (e_ptr > 0 and e_val == 7)
                    @compileError("This NaNBox already has 7 non-pointer types and at least 1 pointer type");
                enm.* = expand(e_val);
                e_val += 1;
            } else {
                @compileError("The field has to fit in 48bits but field " ++ nam ++ " is " ++ @typeName(field));
            }
        }

        if (!floated)
            @compileError("At least one f64 is required");

        break :blk .{ enums, e_ptr > 0 };
    };

    return struct {
        const Self = @This();

        const QNAN: u64 = 0x7ffc000000000000;
        const TAG: u64 = 0x8003000000000000;
        const PTR_TAG: u64 = 0b111;
        const VALUE: u64 = ~(QNAN | TAG);
        const PTR_VALUE: u64 = ~(QNAN | TAG | PTR_TAG);

        pub const Type = @Enum(
            u64,
            std.lang.Type.Enum.Mode.exhaustive,
            info.field_names,
            &enums,
        );

        pub const Error = error{WrongTag};

        value: u64,

        fn from(comptime tag: Type) type {
            return @field(fields, @tagName(tag));
        }

        fn unmask(m: u64) u64 {
            const ret = (m & 0x8000000000000000) | (m & 0x3000000000000);
            return if (HAS_PTR and ret == TAG) ret | (m & PTR_TAG) else ret;
        }

        pub fn of(comptime tag: Type, val: from(tag)) Self {
            return Self{
                .value = if (from(tag) == f64)
                    pun(u64, val)
                else
                    QNAN | @backingInt(tag) | (pun(u64, val) & VALUE),
            };
        }

        pub fn to(self: *const Self, comptime tag: Type) !from(tag) {
            std.debug.print("Msk {b:064} {s}\n", .{ @backingInt(tag), @tagName(tag) });
            std.debug.print("U64 {b:064}\nTag {b:064}\nVal {b:064}\n", .{ self.value, unmask(self.value), self.value & VALUE });

            return if (self.is() == tag)
                self.as(from(tag))
            else
                Error.WrongTag;
        }

        pub fn is(self: *const Self) Type {
            return if ((self.value & QNAN) != QNAN)
                @fromBackingInt(enum_f64)
            else
                @fromBackingInt(unmask(self.value));
        }

        fn as(self: *const Self, typ: type) typ {
            return if (typ == f64)
                pun(f64, self.value)
            else if (typ == void)
                @as(void, {})
            else if (utils.is_type(typ, "pointer"))
                pun(typ, self.value & PTR_VALUE)
            else
                pun(typ, self.value & VALUE);
        }
    };
}
