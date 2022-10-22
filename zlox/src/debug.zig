const std = @import("std");
const chunk = @import("chunk.zig");
const value = @import("value.zig");
const print = std.debug.print;

pub fn disassembleChunk(ch: chunk.Chunk, name: []const u8) void {
    print("== {s} ==\n", .{name});

    var offset: usize = 0;

    while (offset < ch.count) {
        offset = disassembleInstruction(ch, offset);
    }
}

pub fn disassembleInstruction(ch: chunk.Chunk, offset: usize) usize {
    const OP = chunk.OP;
    print("{d:0>4} ", .{offset});
    if (offset > 0 and ch.lines.get(offset) == ch.lines.get(offset-1)) {
        print("   | ", .{});
    } else {
        print("{d:4} ", .{ch.lines.get(offset)});
    }

    return switch (ch.code[offset]) {
        @enumToInt(OP.RETURN) => simpleInstruction("OP_RETURN", offset),
        @enumToInt(OP.CONSTANT) => constantInstruction("OP_CONSTANT", ch, offset),
        else => blk: {
            print("Unknown opcode {}\n", .{ch.code[offset]});
            break :blk offset + 1;
        },
    };
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, ch: chunk.Chunk, offset: usize) usize {
    const constant = ch.code[offset + 1];
    print("{s:<16} {d:4} '", .{name, constant});
    value.printValue(ch.constants.values[constant]);
    print("'\n", .{});
    return offset + 2;
}
