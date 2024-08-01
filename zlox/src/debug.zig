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
        @intFromEnum(OP.EQUAL) => simpleInstruction("OP_EQUAL", offset),
        @intFromEnum(OP.LESS) => simpleInstruction("OP_LESS", offset),
        @intFromEnum(OP.GREATER) => simpleInstruction("OP_GREATER", offset),
        @intFromEnum(OP.NIL) => simpleInstruction("OP_NIL", offset),
        @intFromEnum(OP.NOT) => simpleInstruction("OP_NOT", offset),
        @intFromEnum(OP.CONSTANT) => try constantInstruction("OP_CONSTANT", ch, offset),
        @intFromEnum(OP.DEFINE_GLOBAL) => try constantInstruction("OP_DEFINE_GLOBAL", ch, offset),
        @intFromEnum(OP.GET_GLOBAL) => try constantInstruction("OP_GET_GLOBAL", ch, offset),
        @intFromEnum(OP.SET_GLOBAL) => try constantInstruction("OP_SET_GLOBAL", ch, offset),
        @intFromEnum(OP.PRINT) => simpleInstruction("OP_PRINT", offset),
        @intFromEnum(OP.POP) => simpleInstruction("OP_POP", offset),
        @intFromEnum(OP.GET_LOCAL) => try byteInstruction("OP_GET_LOCAL", ch, offset),
        @intFromEnum(OP.SET_LOCAL) => try byteInstruction("OP_SET_LOCAL", ch, offset),
        @intFromEnum(OP.JUMP_IF_FALSE) => try jumpInstruction("OP_JUMP_IF_FALSE", true, ch, offset),
        @intFromEnum(OP.JUMP) => try jumpInstruction("OP_JUMP", true, ch, offset),
        @intFromEnum(OP.LOOP) => try jumpInstruction("OP_LOOP", false, ch, offset),
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

fn byteInstruction(name: []const u8, ch: chunk.Chunk, offset: usize) !usize {
    print("{s:<16} {d:4}\n", .{name, try ch.code.get(offset+1)});
    return offset + 2;
}

fn jumpInstruction(name: []const u8, sign: bool, ch: chunk.Chunk, offset: usize) !usize {
    const msb: u16 = try ch.code.get(offset + 1);
    const lsb: u16 = try ch.code.get(offset + 2);
    const jump = (msb << 8) | lsb;

    print("{s:<16} {d:4} -> {d}\n", .{name, offset, if (sign) offset + 3 + jump else offset + 3 - jump});
    return offset + 3;
}
