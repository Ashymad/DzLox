const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const Value = @import("value.zig").Value;
const std = @import("std");
const debug = @import("debug.zig");
const compiler = @import("compiler.zig");
const Obj = @import("obj.zig").Obj;
const Callback = @import("vm/callbacks.zig");
const table = @import("table.zig");
const hash = @import("hash.zig");

pub const InterpreterError = compiler.CompilerError || Callback.Error || error{ CompileError, RuntimeError, IndexOutOfBounds, Overflow, DivisionByZero };

pub const VM = struct {
    objects: Obj.List,
    globals: Globals,
    allocator: std.mem.Allocator,

    const Global = struct {
        val: Value,
        con: bool,

        const Self = @This();

        pub fn is_var(g: Self) bool {
            return !g.con;
        }

        pub fn make_var(v: Value) Self {
            return Self {
                .val = v,
                .con = false,
            };
        }

        pub fn make_con(v: Value) Self {
            return Self {
                .val = v,
                .con = true,
            };
        }
    };

    const Globals = table.Table(*const Obj.String, Global, hash.hash_t(*const Obj.String), Obj.String.eql);

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){ .globals = Globals.init(allocator), .objects = Obj.List.init(allocator), .allocator = allocator };
    }

    pub fn interpret(self: *@This(), source: []const u8, dbg: bool) InterpreterError!void {
        const stackSize = 256;

        var chunk = try compiler.Compiler(stackSize).compile(source, &self.objects, self.allocator);
        defer chunk.deinit();

        //try debug.disassembleChunk(chunk, "Main");

        try Interpreter(stackSize).run(self, &chunk, dbg);
    }

    fn Interpreter(size: comptime_int) type {
        return struct {
            ip: [*]const u8,
            chunk: *const   Chunk,
            stackTop: [*]Value,
            stack: [size]Value,
            vm: *VM,

            pub fn run(vm: *VM, chunk: *Chunk, dbg: bool) InterpreterError!void {
                var self = @This(){ .ip = chunk.code.data.ptr, .chunk = chunk, .stack = [_]Value{Value.init({})} ** size, .stackTop = undefined, .vm = vm };
                self.stackTop = &self.stack;
                try self.execute(dbg);
            }

            fn ip_add(self: *@This(), adv: usize) void {
                self.ip += adv;
            }

            fn ip_sub(self: *@This(), adv: usize) void {
                self.ip -= adv;
            }

            fn read_byte(self: *@This()) u8 {
                const out: u8 = self.ip[0];
                self.ip_add(1);
                return out;
            }

            fn read_short(self: *@This()) u16 {
                const msb: u16 = self.read_byte();
                const lsb: u16 = self.read_byte();
                return (msb << 8) | lsb;
            }

            fn read_constant(self: *@This()) Value {
                return self.chunk.constants.get(self.read_byte()) catch unreachable;
            }

            fn read_string(self: *@This()) *const Obj.String {
                return self.read_constant().obj.cast(.String) catch unreachable;
            }

            fn push(self: *@This(), val: Value) void {
                self.stackTop[0] = val;
                self.stackTop += 1;
            }

            fn pop(self: *@This()) Value {
                self.stackTop -= 1;
                return self.stackTop[0];
            }

            fn peek(self: *@This(), distance: usize) Value {
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

            fn execute(self: *@This(), dbg: bool) !void {
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
                        _ = try debug.disassembleInstruction(self.chunk.*, self.instruction_idx());
                    }
                    const instruction: u8 = self.read_byte();
                    switch (instruction) {
                        @intFromEnum(OP.PRINT) => {
                            self.pop().print();
                            std.debug.print("\n", .{});
                        },
                        @intFromEnum(OP.RETURN) => return,
                        @intFromEnum(OP.POP) => _ = self.pop(),
                        @intFromEnum(OP.CONSTANT) => self.push(self.read_constant()),
                        @intFromEnum(OP.NEGATE) => {
                            if (!self.peek(0).is(Value.number)) {
                                self.runtimeError("Operand must be a number.", .{});
                                return InterpreterError.RuntimeError;
                            }
                            self.push(Value.init(-self.pop().number));
                        },
                        @intFromEnum(OP.ADD) => {
                            if (self.peek(0).is(Obj.Type.String)) {
                                try self.binary_op(Obj.Type.String, Obj.Type.String, Callback.concatenate(&self.vm.objects));
                            } else {
                                try self.binary_op(Value.number, Value.number, Callback.add);
                            }
                        },
                        @intFromEnum(OP.JUMP_IF_FALSE) => {
                            const offset = self.read_short();
                            if (!self.peek(0).isTruthy()) {
                                self.ip_add(offset);
                            }
                        },
                        @intFromEnum(OP.JUMP) => {
                            self.ip_add(self.read_short());
                        },
                        @intFromEnum(OP.JUMP_POP) => {
                            self.ip_add(@intFromFloat(self.pop().number));
                        },
                        @intFromEnum(OP.LOOP) => {
                            self.ip_sub(self.read_short());
                        },
                        @intFromEnum(OP.GET_LOCAL) => {
                            self.push(self.stack[self.read_byte()]);
                        },
                        @intFromEnum(OP.SET_LOCAL) => {
                            self.stack[self.read_byte()] = self.peek(0);
                        },
                        @intFromEnum(OP.GET_GLOBAL) => {
                            const name = self.read_string();
                            const global = self.vm.globals.get(name) catch {
                                self.runtimeError("Undefined variable: '{s}'", .{name.slice()});
                                return InterpreterError.RuntimeError;
                            };
                            self.push(global.val);
                        },
                        @intFromEnum(OP.SET_GLOBAL) => {
                            const name = self.read_string();
                            const replaced = self.vm.globals.replace_if(name, Global.make_var(self.peek(0)), Global.is_var) catch {
                                self.runtimeError("Undefined variable: '{s}'", .{name.slice()});
                                return InterpreterError.RuntimeError;
                            };
                            if (!replaced) {
                                self.runtimeError("Cannot assign to a constant: '{s}'", .{name.slice()});
                                return InterpreterError.RuntimeError;
                            }
                        },
                        @intFromEnum(OP.GET_INDEX) => {
                            const key = self.pop();
                            const obj = self.pop();
                            var pushed = false;
                            if (obj.is(Value.obj)) {
                                switch(obj.obj.type) {
                                    .Function => {},
                                    inline else => |tp| {
                                        self.push((obj.obj.cast(tp) catch unreachable).get(key) catch Value.init({}));
                                        pushed = true;
                                    },
                                }
                            }
                            if (!pushed) {
                                self.runtimeError("Cannot index a value of type {s}", .{obj.typeName()});
                                return InterpreterError.RuntimeError;
                            }
                        },
                        @intFromEnum(OP.SET_INDEX) => {
                            const val = self.pop();
                            const key = self.pop();
                            const obj = self.pop();
                            if (!obj.is(Obj.Type.Table)) {
                                self.runtimeError("Cannot index a non-table value", .{});
                                return InterpreterError.RuntimeError;
                            }
                            var m = obj.obj.cast(.Table) catch unreachable;
                            if (val.is(Value.nil)) {
                                m.delete(key);
                            } else {
                                _ = try m.set(key, val);
                            }
                            self.push(val);
                        },
                        @intFromEnum(OP.DEFINE_GLOBAL) => _ = try self.vm.globals.set(self.read_string(), Global.make_var(self.pop())),
                        @intFromEnum(OP.DEFINE_GLOBAL_CONSTANT) => _ = try self.vm.globals.set(self.read_string(), Global.make_con(self.pop())),
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
            }
        };
    }

    pub fn deinit(self: *@This()) void {
        self.objects.deinit();
        self.globals.deinit();
    }
};
