const std = @import("std");
const NaNBox = @import("src/lib::nanbox.zig").NaNBox;

pub fn main(_: std.process.Init) anyerror!u8 {
    const Box = NaNBox(.{
        .u32 = u32,
        .void = void,
        .pf64 = *const f64,
        .f64 = f64,
        .pf32 = *const f32,
    });

    const p: f32 = 123;

    const box = Box.of(.pf32, &p);

    std.debug.print("Box contains: {any}\n", .{(try box.to(.pf32)).*});

    return 0;
}
