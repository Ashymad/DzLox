const std = @import("std");

pub fn copy_const(T: type, U: type) type {
    comptime var info = @typeInfo(U);
    info.Pointer.is_const = @typeInfo(T).Pointer.is_const;
    return @Type(info);
}

pub fn typeFromTag(T: type, comptime tag: std.meta.Tag(T)) type {
    return @TypeOf(@field(@unionInit(T, @tagName(tag), undefined), @tagName(tag)));

}

pub fn tagFromType(T: type, U: type) std.meta.Tag(T) {
    inline for (@typeInfo(T).Union.fields) |field| {
        if (U == field.type) {
            return @field(T, field.name);
        }
    }
    @compileError("No matching tag for type " ++ @typeName(U) ++ " in Union " ++ @typeName(T));
}

pub fn fn_error(comptime fun: anytype) type {
    return @typeInfo(@typeInfo(@TypeOf(fun)).Fn.return_type.?).ErrorUnion.error_set;
}
