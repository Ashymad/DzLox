const std = @import("std");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

pub fn main() anyerror!u8 {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!allocator.deinit());
    var ch = try chunk.Chunk.init(allocator.allocator());
    defer ch.deinit();
    var VM = vm.VM.init();
    defer VM.deinit();

    try ch.write(@enumToInt(chunk.OP.CONSTANT), 123);
    try ch.write(try ch.addConstant(1.2), 123);

    try ch.write(@enumToInt(chunk.OP.CONSTANT), 123);
    try ch.write(try ch.addConstant(3.4), 123);

    try ch.write(@enumToInt(chunk.OP.ADD), 123);

    try ch.write(@enumToInt(chunk.OP.CONSTANT), 123);
    try ch.write(try ch.addConstant(5.6), 123);

    try ch.write(@enumToInt(chunk.OP.DIVIDE), 123);

    try ch.write(@enumToInt(chunk.OP.NEGATE), 123);

    try ch.write(@enumToInt(chunk.OP.RETURN), 123);

    try VM.interpret(&ch);
    return 0;
}
