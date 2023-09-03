const std = @import("std");
const chunk = @import("chunk.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

fn testChunk() anyerror!void {
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(allocator.deinit() == std.heap.Check.ok);
    var ch = try chunk.Chunk.init(allocator.allocator());
    defer ch.deinit();
    var VM = vm.VM.init();
    defer VM.deinit();

    try ch.writeOP(chunk.OP.CONSTANT, 123);
    try ch.write(try ch.addConstant(1.2), 123);

    try ch.writeOP(chunk.OP.CONSTANT, 123);
    try ch.write(try ch.addConstant(3.4), 123);

    try ch.writeOP(chunk.OP.ADD, 123);

    try ch.writeOP(chunk.OP.CONSTANT, 123);
    try ch.write(try ch.addConstant(5.6), 123);

    try ch.writeOP(chunk.OP.DIVIDE, 123);

    try ch.writeOP(chunk.OP.NEGATE, 123);

    try ch.writeOP(chunk.OP.RETURN, 123);

    try VM.interpretChunk(&ch);
}
