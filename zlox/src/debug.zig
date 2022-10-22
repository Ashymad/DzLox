const std = @import("std");
const chunk = @import("chunk.zig");
const OP = chunk.OP;

pub fn disassembleChunk(ch: chunk.Chunk, name: []const u8) !void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < ch.count) {
        offset = disassembleInstruction(ch.code.?, offset);
    }
}

pub fn disassembleInstruction(code: []u8, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});

    return switch (code[offset]) {
        @enumToInt(OP.RETURN) => simpleInstruction("OP_RETURN", offset),
        else => blk: {
            std.debug.print("Unknown opcode {}\n", .{code[offset]});
            break :blk offset + 1;
        },
    };
}

pub fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
