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

    const op = try ch.code.get(offset);
    const name = @tagName(@as(OP, @enumFromInt(op)));

    return switch (op) {
        @intFromEnum(OP.RETURN) => simpleInstruction(name, offset),
        @intFromEnum(OP.NEGATE) => simpleInstruction(name, offset),
        @intFromEnum(OP.ADD) => simpleInstruction(name, offset),
        @intFromEnum(OP.SUBTRACT) => simpleInstruction(name, offset),
        @intFromEnum(OP.DIVIDE) => simpleInstruction(name, offset),
        @intFromEnum(OP.MULTIPLY) => simpleInstruction(name, offset),
        @intFromEnum(OP.TRUE) => simpleInstruction(name, offset),
        @intFromEnum(OP.FALSE) => simpleInstruction(name, offset),
        @intFromEnum(OP.EQUAL) => simpleInstruction(name, offset),
        @intFromEnum(OP.LESS) => simpleInstruction(name, offset),
        @intFromEnum(OP.GREATER) => simpleInstruction(name, offset),
        @intFromEnum(OP.NIL) => simpleInstruction(name, offset),
        @intFromEnum(OP.NOT) => simpleInstruction(name, offset),
        @intFromEnum(OP.CONSTANT) => try constantInstruction(name, ch, offset),
        @intFromEnum(OP.DEFINE_GLOBAL) => try constantInstruction(name, ch, offset),
        @intFromEnum(OP.DEFINE_GLOBAL_CONSTANT) => try constantInstruction(name, ch, offset),
        @intFromEnum(OP.GET_GLOBAL) => try constantInstruction(name, ch, offset),
        @intFromEnum(OP.SET_GLOBAL) => try constantInstruction(name, ch, offset),
        @intFromEnum(OP.PRINT) => simpleInstruction(name, offset),
        @intFromEnum(OP.POP) => simpleInstruction(name, offset),
        @intFromEnum(OP.GET_LOCAL) => try byteInstruction(name, ch, offset),
        @intFromEnum(OP.SET_LOCAL) => try byteInstruction(name, ch, offset),
        @intFromEnum(OP.JUMP_IF_FALSE) => try jumpInstruction(name, true, ch, offset),
        @intFromEnum(OP.JUMP_POP) => simpleInstruction(name, offset),
        @intFromEnum(OP.JUMP) => try jumpInstruction(name, true, ch, offset),
        @intFromEnum(OP.LOOP) => try jumpInstruction(name, false, ch, offset),
        @intFromEnum(OP.SET_INDEX) => simpleInstruction(name, offset),
        @intFromEnum(OP.GET_INDEX) => simpleInstruction(name, offset),
        else => blk: {
            print("Unknown opcode {d} {s}\n", .{op, name});
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
    print("{s:<32} {d:4} '", .{ name, constant });
    (try ch.constants.get(constant)).print();
    print("'\n", .{});
    return offset + 2;
}

fn byteInstruction(name: []const u8, ch: chunk.Chunk, offset: usize) !usize {
    print("{s:<32} {d:4}\n", .{name, try ch.code.get(offset+1)});
    return offset + 2;
}

fn jumpInstruction(name: []const u8, sign: bool, ch: chunk.Chunk, offset: usize) !usize {
    const msb: u16 = try ch.code.get(offset + 1);
    const lsb: u16 = try ch.code.get(offset + 2);
    const jump = (msb << 8) | lsb;

    print("{s:<32} {d:4} -> {d}\n", .{name, offset, if (sign) offset + 3 + jump else offset + 3 - jump});
    return offset + 3;
}
