const std = @import("std");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");

pub fn main() anyerror!u8 {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!allocator.deinit());
    var ch = chunk.Chunk.init(allocator.allocator());
    try ch.write(@enumToInt(chunk.OP.RETURN));
    try debug.disassembleChunk(ch, "test chunk");
    ch.free();
    return 0;
}
