const std = @import("std");
const chunk = @import("chunk.zig");
const value = @import("value.zig");
const print = std.debug.print;

pub fn disassembleChunk(ch: chunk.Chunk, name: []const u8) !void {
    print("== {s} ==\n", .{name});

    var offset: usize = 0;

    while (offset < ch.code.len) {
        offset = try disassembleInstruction(ch, offset);
    }
}

pub fn disassembleInstruction(ch: chunk.Chunk, offset: usize) !usize {
    const OP = chunk.OP;
    print("{d:0>4} ", .{offset});
    if (offset > 0 and (try ch.lines.get(offset)) == (try ch.lines.get(offset - 1))) {
        print("   | ", .{});
    } else {
        print("{d:4} ", .{try ch.lines.get(offset)});
    }

    return switch (try ch.code.get(offset)) {
        @intFromEnum(OP.RETURN) => simpleInstruction("OP_RETURN", offset),
        @intFromEnum(OP.NEGATE) => simpleInstruction("OP_NEGATE", offset),
        @intFromEnum(OP.ADD) => simpleInstruction("OP_ADD", offset),
        @intFromEnum(OP.SUBTRACT) => simpleInstruction("OP_SUBTRACT", offset),
        @intFromEnum(OP.DIVIDE) => simpleInstruction("OP_DIVIDE", offset),
        @intFromEnum(OP.MULTIPLY) => simpleInstruction("OP_MULTIPLY", offset),
        @intFromEnum(OP.TRUE) => simpleInstruction("OP_TRUE", offset),
        @intFromEnum(OP.FALSE) => simpleInstruction("OP_FALSE", offset),
        @intFromEnum(OP.NIL) => simpleInstruction("OP_NIL", offset),
        @intFromEnum(OP.NOT) => simpleInstruction("OP_NOT", offset),
        @intFromEnum(OP.CONSTANT) => try constantInstruction("OP_CONSTANT", ch, offset),
        else => blk: {
            print("Unknown opcode {}\n", .{try ch.code.get(offset)});
            break :blk offset + 1;
        },
    };
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, ch: chunk.Chunk, offset: usize) !usize {
    const constant = try ch.code.get(offset + 1);
    print("{s:<16} {d:4} '", .{ name, constant });
    (try ch.constants.get(constant)).print();
    print("'\n", .{});
    return offset + 2;
}
