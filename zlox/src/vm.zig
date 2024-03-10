const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const Value = @import("value.zig").Value;
const std = @import("std");
const debug = @import("debug.zig");
const wrp = @import("wrap.zig");
const compiler = @import("compiler.zig");

pub const InterpreterError = compiler.CompilerError || error{ OutOfMemory, CompileError, RuntimeError, IndexOutOfBounds, Overflow, DivisionByZero };

pub const VM = struct {
    ip: [*]const u8,
    chunk: *const Chunk,
    stack: stackType,
    stackTop: [*]Value,

    const stackSize = 256;
    const stackType = [stackSize]Value;

    pub fn init() @This() {
        var ret = @This(){
            .ip = undefined,
            .chunk = undefined,
            .stack = [_]Value{Value{ .number = 0 }} ** stackSize,
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

    pub fn interpret(self: *@This(), source: []const u8, allocator: std.mem.Allocator) InterpreterError!void {
        var chunk = try Chunk.init(allocator);
        defer chunk.deinit();

        try compiler.Compiler.compile(source, &chunk);

        try self.interpretChunk(&chunk);
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

    fn read_constant(self: *@This()) Value {
        return self.chunk.constants.data[self.read_byte()];
    }

    fn push(self: *@This(), val: Value) void {
        self.stackTop[0] = val;
        self.stackTop += 1;
    }

    pub fn pop(self: *@This()) Value {
        self.stackTop -= 1;
        return self.stackTop[0];
    }

    pub fn peek(self: *const @This(), distance: usize) Value {
        return (self.stackTop - (1 + distance))[0];
    }

    fn binary_op(self: *@This(), comptime tag: Value.Tag, op: fn (type, Value.tagType(tag), Value.tagType(tag)) Value.tagType(tag)) !void {
        const b = self.pop();
        const a = self.pop();
        if (a.is(tag) and b.is(tag)) {
            self.push(Value.new(tag, op(Value.tagType(tag), a.get(tag), b.get(tag))));
        } else {
            self.runtimeError("Operands have invalid types, expected: {s}", .{@tagName(tag)});
            return InterpreterError.RuntimeError;
        }
    }

    fn instruction_idx(self: *const @This()) usize {
        return @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.data.ptr);
    }

    fn run(self: *@This(), comptime dbg: bool) !void {
        while (true) {
            if (dbg) {
                std.debug.print("          ", .{});
                var stackPtr: [*]Value = &self.stack;
                while (stackPtr != self.stackTop) : (stackPtr += 1) {
                    std.debug.print("[ ", .{});
                    stackPtr[0].print();
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});
            }
            _ = try debug.disassembleInstruction(self.chunk.*, self.instruction_idx());
            const instruction: u8 = self.read_byte();
            switch (instruction) {
                @intFromEnum(OP.RETURN) => {
                    self.pop().print();
                    std.debug.print("\n", .{});
                    return;
                },
                @intFromEnum(OP.CONSTANT) => {
                    const constant = self.read_constant();
                    self.push(constant);
                },
                @intFromEnum(OP.NEGATE) => {
                    if (!self.peek(0).is(Value.number)) {
                        self.runtimeError("Operand must be a number.", .{});
                        return InterpreterError.RuntimeError;
                    }
                    self.push(Value{ .number = -self.pop().number });
                },
                @intFromEnum(OP.ADD) => try self.binary_op(Value.number, wrp.add),
                @intFromEnum(OP.SUBTRACT) => try self.binary_op(Value.number, wrp.sub),
                @intFromEnum(OP.MULTIPLY) => try self.binary_op(Value.number, wrp.mul),
                @intFromEnum(OP.DIVIDE) => try self.binary_op(Value.number, wrp.div),
                @intFromEnum(OP.TRUE) => self.push(Value{ .bool = true }),
                @intFromEnum(OP.FALSE) => self.push(Value{ .bool = false }),
                @intFromEnum(OP.NIL) => self.push(Value{ .nil = undefined }),
                @intFromEnum(OP.NOT) => self.push(Value{ .bool = !self.pop().isTruthy() }),
                else => return InterpreterError.CompileError,
            }
        }
    }

    fn runtimeError(self: *@This(), comptime fmt: []const u8, args: anytype) void {
        std.debug.print(fmt, args);
        std.debug.print("\n[line {d}] in script\n", .{self.chunk.lines.get(self.instruction_idx()) catch 0});
        self.resetStack();
    }

    pub fn deinit(_: *@This()) void {}
};
