const std = @import("std");

pub fn with_size(T: type, comptime size: std.builtin.Type.Pointer.Size) type {
    return mod_ptr_t(T, "size", size);
}

pub fn copy_const(T: type, U: type) type {
    return mod_ptr_t(U, "const", @typeInfo(T).pointer.attrs.@"const");
}

pub fn mod_ptr_t(T: type, comptime field: []const u8, comptime val: anytype) type {
    comptime var new = @typeInfo(T).pointer;

    if (@hasField(std.lang.Type.Pointer.Attributes, field)) {
        @field(new.attrs, field) = val;
    } else {
        @field(new, field) = val;
    }

    return @Pointer(
        new.size,
        new.attrs,
        new.child,
        std.lang.Type.Pointer.sentinel(new),
    );
}

pub fn enum_len(T: type) usize {
    return @typeInfo(T).@"enum".field_names.len;
}

pub fn is_type(T: type, comptime name: []const u8) bool {
    return @as(std.meta.Tag(std.builtin.Type), @typeInfo(T)) == @field(std.meta.Tag(std.builtin.Type), name);
}

pub fn typeFromTag(T: type, comptime tag: std.meta.Tag(T)) type {
    return @TypeOf(@field(@unionInit(T, @tagName(tag), undefined), @tagName(tag)));
}

pub fn tagFromType(T: type, U: type) std.meta.Tag(T) {
    const info = @typeInfo(T).@"union";
    inline for (info.field_types, info.field_names) |field_type, field_name| {
        if (U == field_type) {
            return @field(T, field_name);
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

pub fn pack_t(s: type) type {
    const info = @typeInfo(s).@"struct";
    const Attributes = std.lang.Type.Struct.FieldAttributes;

    return @Struct(
        std.lang.Type.ContainerLayout.@"packed",
        info.backing_integer,
        info.field_names,
        info.field_types,
        &@as(
            [info.field_attrs.len]Attributes,
            @splat(Attributes{
                .@"align" = null,
                .@"comptime" = false,
            }),
        ),
    );
}

pub fn pack(s: anytype) pack_t(@TypeOf(s)) {
    const T = @TypeOf(s);
    const fields = @typeInfo(T).@"struct".field_names;
    var packed_struct: pack_t(T) = undefined;

    inline for (fields) |field| {
        @field(packed_struct, field) = @field(s, field);
    }

    return packed_struct;
}
