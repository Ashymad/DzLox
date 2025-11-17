const std = @import("std");

pub fn copy_const(T: type, U: type) type {
    comptime var info = @typeInfo(U);
    info.pointer.is_const = @typeInfo(T).pointer.is_const;
    return @Type(info);
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
    const oldFields = @typeInfo(s).@"struct".fields;
    var newFields: [oldFields.len]std.builtin.Type.StructField = undefined;

    for (oldFields, &newFields) |oldField, *newField| {
        newField.* = oldField;
        newField.alignment = 0;
        newField.is_comptime = false;
    }

    return @Type(std.builtin.Type{.@"struct" = .{
        .layout = std.builtin.Type.ContainerLayout.@"packed",
        .fields = &newFields,
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_tuple = false
    }});
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
