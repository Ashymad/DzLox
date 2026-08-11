const std = @import("std");

pub fn copy_const(T: type, U: type) type {
    const info = @typeInfo(U).pointer;
    return @Pointer(
        info.size,
        std.builtin.Type.Pointer.Attributes{
            .@"const" = @typeInfo(T).pointer.is_const,
            .@"volatile" = info.is_volatile,
            .@"allowzero" = info.is_allowzero,
            .@"addrspace" = info.address_space,
            .@"align" = info.alignment
        },
        info.child,
        std.builtin.Type.Pointer.sentinel(info)
    );
}

pub fn typeFromTag(T: type, comptime tag: std.meta.Tag(T)) type {
    return @TypeOf(@field(@unionInit(T, @tagName(tag), undefined), @tagName(tag)));

}

pub fn tagFromType(T: type, U: type) std.meta.Tag(T) {
    inline for (@typeInfo(T).@"union".fields) |field| {
        if (U == field.type) {
            return @field(T, field.name);
        }
    }
    @compileError("No matching tag for type " ++ @typeName(U) ++ " in Union " ++ @typeName(T));
}

pub fn fn_error(comptime fun: anytype) type {
    return @typeInfo(@typeInfo(@TypeOf(fun)).@"fn".return_type.?).error_union.error_set;
}

pub fn param_type(comptime fun: anytype, idx: comptime_int) type {
    return @TypeOf(fun).@"fn".params[idx].type.?;
}

pub fn if_not_null(comptime fun: anytype) fn (?param_type(fun, 0)) void {
    return struct {
        pub fn function(arg: ?param_type(fun, 0)) void {
            if (arg) |a| {
                _ = fun(a);
            }
        }
    }.function;
}

pub fn make_packed_t(s: type) type {
    const info = @typeInfo(s).@"struct";
    const Attributes = std.builtin.Type.StructField.Attributes;

    const attr = Attributes{
        .@"align" = null,
        .@"comptime" = false,
    };

    const attrs = [_]Attributes{attr} ** info.fields.len;
    comptime var names: [info.fields.len][]const u8 = undefined;
    comptime var types: [info.fields.len]type = undefined;
    
    inline for (info.fields, 0..) |field, i| {
        names[i] = field.name;
        types[i] = field.type;
    }

    return @Struct(
        std.builtin.Type.ContainerLayout.@"packed",
        info.backing_integer,
        &names,
        &types,
        &attrs
    );
}

pub fn make_packed(s: anytype) make_packed_t(@TypeOf(s)) {
    const T = @TypeOf(s);
    const fields = @typeInfo(T).@"struct".fields;
    var packd: make_packed_t(T) = undefined;

    for (fields) |field| {
        @field(packd, field.name) = @field(s, field.name);
    }

    return packd;
}
