const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const Value = @import("value.zig").Value;
const std = @import("std");
const debug = @import("debug.zig");
const compiler = @import("compiler.zig");
const Obj = @import("obj.zig").Obj;
const Callback = @import("vm_callbacks.zig");

pub const InterpreterError = compiler.CompilerError || Callback.Error || error{ CompileError, RuntimeError, IndexOutOfBounds, Overflow, DivisionByZero };

pub const VM = struct {
    ip: [*]const u8,
    chunk: *Chunk,
    objects: *Obj.List,
    stack: stackType,
    stackTop: [*]Value,

    const stackSize = 256;
    const stackType = [stackSize]Value;

    pub fn init() @This() {
        var ret = @This(){
            .ip = undefined,
            .chunk = undefined,
            .objects = undefined,
            .stack = [_]Value{Value.init({})} ** stackSize,
            .stackTop = undefined,
        };
        ret.stackTop = &ret.stack;
        return ret;
    }

    pub fn interpretChunk(self: *@This(), chunk: *Chunk) InterpreterError!void {
        self.resetStack();
        self.chunk = chunk;
        self.ip = chunk.code.data.ptr;
        try self.run(true);
    }

    pub fn interpret(self: *@This(), source: []const u8, allocator: std.mem.Allocator) InterpreterError!void {
        var result = try compiler.Compiler.compile(source, allocator);
        defer result.deinit();
        self.objects = &result.objects;

        try self.interpretChunk(&result.chunk);
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

    pub fn peek(self: *@This(), distance: usize) Value {
        return (self.stackTop - (1 + distance))[0];
    }

    fn binary_op(self: *@This(), comptime in_tag: anytype, comptime out_tag: anytype, op: Callback.Type(in_tag, out_tag)) InterpreterError!void {
        const b = self.pop();
        const a = self.pop();
        if (a.is(in_tag) and b.is(in_tag)) {
            self.push(Value.init(try op.call(a.get(in_tag), b.get(in_tag))));
        } else {
            self.runtimeError("Operands have invalid types, expected: {s}", .{@tagName(in_tag)});
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
                    self.push(Value.init(-self.pop().number));
                },
                @intFromEnum(OP.ADD) => {
                    if (self.peek(0).is(Obj.Type.String)) {
                        try self.binary_op(Obj.Type.String, Obj.Type.String, Callback.concatenate(self.objects));
                    } else {
                        try self.binary_op(Value.number, Value.number, Callback.add);
                    }
                },
                @intFromEnum(OP.SUBTRACT) => try self.binary_op(Value.number, Value.number, Callback.sub),
                @intFromEnum(OP.MULTIPLY) => try self.binary_op(Value.number, Value.number, Callback.mul),
                @intFromEnum(OP.DIVIDE) => try self.binary_op(Value.number, Value.number, Callback.div),
                @intFromEnum(OP.TRUE) => self.push(Value.init(true)),
                @intFromEnum(OP.FALSE) => self.push(Value.init(false)),
                @intFromEnum(OP.EQUAL) => self.push(Value.init(self.pop().eql(self.pop()))),
                @intFromEnum(OP.LESS) => try self.binary_op(Value.number, Value.bool, Callback.less),
                @intFromEnum(OP.GREATER) => try self.binary_op(Value.number, Value.bool, Callback.more),
                @intFromEnum(OP.NIL) => self.push(Value.init({})),
                @intFromEnum(OP.NOT) => self.push(Value.init(!self.pop().isTruthy())),
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
