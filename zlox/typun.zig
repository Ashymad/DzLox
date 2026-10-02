const std = @import("std");
const utils = @import("src/lib::utils.zig");
const assert = std.debug.assert;
const NaNBox = @import("src/lib::nanbox.zig").NaNBox;
const Packer = @import("src/lib::nanbox.zig").Packer;

fn typetypeof(Box: type, comptime tag: Box.Type) type {
    const T = Box.typeof(tag);

    return if (utils.is_type(T, "pointer"))
        @typeInfo(T).pointer.child
    else
        T;
}

pub fn dbg(box: anytype, comptime tag: @TypeOf(box).Type) @TypeOf(box) {
    const Box = @TypeOf(box);

    std.debug.print("U64: {b:064}\n", .{box.value});
    std.debug.print("Flg: {b:064}\n", .{Box.flag(tag).flag});
    std.debug.print("Msk: {b:064}\n", .{Box.flag(tag).mask});
    std.debug.print("Dec: {b:064}\n", .{Box.flag(tag).decode(box.value)});
    std.debug.print("Tru: {any}\n", .{Box.flag(tag).true});
    std.debug.print("Chk: {any}\n", .{Box.flag(tag).check(box.value)});

    return box;
}

pub fn tst(Box: type, comptime tag: Box.Type, val: typetypeof(Box, tag)) !void {
    const T = Box.typeof(tag);

    std.debug.print("Test tag {s}, type {s}, value {any}\n", .{ @tagName(tag), @typeName(T), val });

    const ret = if (comptime utils.is_type(T, "pointer"))
        (try dbg(Box.of(tag, &val), tag).to(tag)).*
    else
        try dbg(Box.of(tag, val), tag).to(tag);

    assert(ret == val);
}

pub fn test1() !void {
    const Box = NaNBox(.{
        .u32 = u32,
        .i24 = i24,
        .void = void,
        .pf64 = *const f64,
        .f64 = f64,
        .pf32 = *const f32,
        .true = void,
        .false = void,
    });

    try tst(Box, .u32, 123);
    try tst(Box, .pf32, 123);
    try tst(Box, .i24, -13);
    try tst(Box, .f64, 14.123);
    try tst(Box, .void, {});
    try tst(Box, .true, {});
    try tst(Box, .false, {});
}

pub fn printpack(comptime max: u6, packer: Packer(max)) void {
    for (packer.matrix) |val|
        if (val) |v|
            std.debug.print("{b:0" ++ std.fmt.comptimePrint("{d}", .{max}) ++ "} ", .{v})
        else
            std.debug.print("{s:" ++ std.fmt.comptimePrint("{d}", .{max}) ++ "} ", .{"null"});
    std.debug.print("\n", .{});
}

pub fn main(_: std.process.Init) anyerror!u8 {
    var packer = Packer(5).init();

    printpack(5, packer);
    _ = packer.next(4);
    printpack(5, packer);
    _ = packer.next(2);
    printpack(5, packer);
    _ = packer.next(3);
    printpack(5, packer);

    try test1();

    return 0;
}
