const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const value = @import("value.zig");
const std = @import("std");
const debug = @import("debug.zig");
const wrp = @import("wrap.zig");
const compiler = @import("compiler.zig");

pub const InterpreterError = compiler.CompilerError || error{ CompileError, RuntimeError, IndexOutOfBounds, Overflow, DivisionByZero };

pub const VM = struct {
    ip: [*]const u8,
    chunk: *const Chunk,
    stack: stackType,
    stackTop: [*]value.Value,

    const stackSize = 256;
    const stackType = [stackSize]value.Value;

    pub fn init() @This() {
        var ret = @This(){
            .ip = undefined,
            .chunk = undefined,
            .stack = std.mem.zeroes(@This().stackType),
            .stackTop = undefined,
        };
        ret.stackTop = &ret.stack;
        return ret;
    }

    pub fn interpretChunk(self: *@This(), chunk: *const Chunk) InterpreterError!void {
        self.resetStack();
        self.chunk = chunk;
        self.ip = chunk.code.data.ptr;
        try self.run(true);
    }

    pub fn interpret(self: *@This(), source: []const u8) !void {
        try compiler.compile(source);
        self.resetStack();
    }

    fn resetStack(self: *@This()) void {
        self.stackTop = &self.stack;
    }

    fn read_byte(self: *@This()) u8 {
        const out: u8 = self.ip[0];
        self.ip += 1;
        return out;
    }

    fn read_constant(self: *@This()) value.Value {
        return self.chunk.constants.data[self.read_byte()];
    }

    fn push(self: *@This(), val: value.Value) void {
        self.stackTop[0] = val;
        self.stackTop += 1;
    }

    pub fn pop(self: *@This()) value.Value {
        self.stackTop -= 1;
        return self.stackTop[0];
    }

    fn binary_op(self: *@This(), comptime op: fn (comptime T: type, value.Value, value.Value) value.Value) void {
        const b = self.pop();
        const a = self.pop();
        self.push(op(value.Value, a, b));
    }

    fn run(self: *@This(), comptime dbg: bool) !void {
        while (true) {
            if (dbg) {
                std.debug.print("          ", .{});
                var stackPtr: [*]value.Value = &self.stack;
                while (stackPtr != self.stackTop) : (stackPtr += 1) {
                    std.debug.print("[ ", .{});
                    value.printValue(stackPtr[0]);
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});
            }
            _ = try debug.disassembleInstruction(self.chunk.*, @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.data.ptr));
            const instruction: u8 = self.read_byte();
            switch (instruction) {
                @intFromEnum(OP.RETURN) => {
                    return;
                },
                @intFromEnum(OP.CONSTANT) => {
                    const constant = self.read_constant();
                    self.push(constant);
                },
                @intFromEnum(OP.NEGATE) => self.push(-self.pop()),
                @intFromEnum(OP.ADD) => self.binary_op(wrp.add),
                @intFromEnum(OP.SUBTRACT) => self.binary_op(wrp.sub),
                @intFromEnum(OP.MULTIPLY) => self.binary_op(wrp.mul),
                @intFromEnum(OP.DIVIDE) => self.binary_op(wrp.div),
                else => return InterpreterError.CompileError,
            }
        }
    }

    pub fn deinit(_: *@This()) void {}
};
