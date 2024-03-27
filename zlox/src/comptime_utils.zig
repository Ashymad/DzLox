pub fn copy_const(T: type, U: type) type {
    comptime var info = @typeInfo(U);
    info.Pointer.is_const = @typeInfo(T).Pointer.is_const;
    return @Type(info);
}
