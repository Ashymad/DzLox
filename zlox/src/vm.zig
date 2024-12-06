const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const Value = @import("value.zig").Value;
const std = @import("std");
const debug = @import("debug.zig");
const compiler = @import("compiler.zig");
const GC = @import("gc.zig").GC;
const Obj = GC.Obj;
const Callback = @import("vm/callbacks.zig");
const table = @import("table.zig");
const list = @import("list.zig");
const hash = @import("hash.zig");
const utils = @import("comptime_utils.zig");
const vm_native = @import("vm/native.zig");

pub const InterpreterError = Obj.Error || compiler.CompilerError || Callback.Error || error{ CompileError, RuntimeError, StackOverflow, IndexOutOfBounds, Overflow, DivisionByZero };

pub const VM = struct {
    objects: GC,
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

    const CallFrame = struct {
        callee: *const Obj,
        ip: [*]const u8,
        slots: [*]Value,
        chunk: *const Chunk,

        pub fn init(comptime tp: Obj.Type, callee: *const tp.get(), slots: [*]Value) @This() {
            return switch(tp) {
                .Function => @This() {
                    .callee = callee.cast(),
                    .ip = callee.chunk.code.data.ptr,
                    .chunk = callee.chunk,
                    .slots = slots
                },
                .Closure => @This() {
                    .callee = callee.cast(),
                    .ip = callee.function.chunk.code.data.ptr,
                    .chunk = callee.function.chunk,
                    .slots = slots
                },
                else => @compileError("Invalid type")
            };
        }
    };

    fn defineNative(self: *@This(), name: []const u8, arity_min: u8, arity_max: u8, fun: Obj.Native.Fn) !void {
        const nameObj = try self.objects.emplace(.String, &.{name});
        const funObj = try self.objects.emplace_cast(.Native, Obj.Native.Arg{.fun = fun, .name = name, .arity_min = arity_min, .arity_max = arity_max});
        _ = try self.globals.set(nameObj, Global.make_con(Value.init(funObj)));
    }

    pub fn init(allocator: std.mem.Allocator) !@This() {
        var self = @This(){ .globals = Globals.init(allocator), .objects = try GC.init(allocator), .allocator = allocator };

        try self.defineNative("clock", 0, 0, vm_native.Clock.clock);
        try self.defineNative("put", 1, 1, vm_native.put);
        try self.defineNative("table", 0, Obj.Native.ArityMax, vm_native.table);
        try self.defineNative("list", 0, Obj.Native.ArityMax, vm_native.list);

        try vm_native.Clock.set_start();

        return self;
    }

    pub fn interpret(self: *@This(), source: []const u8, dbg: bool) InterpreterError!void {
        const callstack_size = 64;
        const stack_size = 256;

        const function = try compiler.Compiler(stack_size).compile(source, &self.objects);

        if (dbg) try debug.disassembleChunk(function.chunk, "Main");

        try Interpreter(callstack_size, stack_size).run(self, function, dbg);
    }

    fn Interpreter(callstack_size: comptime_int, stack_size: comptime_int) type {
        return struct {
            const List = list.List(*Obj.Upvalue);

            frames: [callstack_size]CallFrame,
            frameCount: usize,
            stackTop: [*]Value,
            stack: [stack_size]Value,
            vm: *VM,
            open_upvalues: List,

            pub fn run(vm: *VM, function: *Obj.Function, dbg: bool) InterpreterError!void {
                var self = @This(){
                    .frames = [_]CallFrame{undefined} ** callstack_size,
                    .frameCount = 1,
                    .stack = [_]Value{Value.init({})} ** stack_size,
                    .stackTop = undefined,
                    .vm = vm,
                    .open_upvalues = List.init(vm.allocator)
                };

                defer self.open_upvalues.free();

                self.stackTop = &self.stack;
                self.frames[0] = CallFrame.init(.Function, function, self.stackTop);
                self.push(Value.init(function.cast()));
                try self.execute(dbg);
            }

            fn frame(self: anytype) utils.copy_const(@TypeOf(self), *CallFrame) {
                return &self.frames[self.frameCount - 1];
            }

            fn ip(self: *const @This()) [*]const u8 {
                return self.frame().ip;
            }

            fn ip_add(self: *@This(), adv: usize) void {
                self.frame().ip += adv;
            }

            fn ip_sub(self: *@This(), adv: usize) void {
                self.frame().ip -= adv;
            }

            fn read_byte(self: *@This()) u8 {
                const out: u8 = self.ip()[0];
                self.ip_add(1);
                return out;
            }

            fn read_short(self: *@This()) u16 {
                const msb: u16 = self.read_byte();
                const lsb: u16 = self.read_byte();
                return (msb << 8) | lsb;
            }

            fn read_constant(self: *@This()) Value {
                return self.frame().chunk.constants.get(self.read_byte()) catch unreachable;
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

            fn callValue(self: *@This(), callee: Value, argCount: u8) !void {
                if(callee.is(Obj.Type.Function)) {
                    try self.callFunction(callee.obj.cast(.Function) catch unreachable, argCount);
                } else if(callee.is(Obj.Type.Closure)) {
                    try self.callClosure(callee.obj.cast(.Closure) catch unreachable, argCount);
                } else if(callee.is(Obj.Type.Native)) {
                    try self.callNative(callee.obj.cast(.Native) catch unreachable, argCount);
                } else {
                    self.runtimeError("Can only call functions and classes", .{});
                    return InterpreterError.RuntimeError;
                }
            }

            fn callClosure(self: *@This(), callee: *Obj.Closure, argCount: u8) !void {
                if (argCount != callee.function.arity) {
                    self.runtimeError("Expected {d} arguments but got {d}", .{callee.function.arity, argCount});
                    return InterpreterError.RuntimeError;
                }
                if (self.frameCount == callstack_size - 1)
                    return InterpreterError.StackOverflow;
                self.frameCount += 1;
                self.frames[self.frameCount - 1] = CallFrame.init(.Closure, callee, self.stackTop - argCount - 1);
            }


            fn callFunction(self: *@This(), callee: *Obj.Function, argCount: u8) !void {
                if (argCount != callee.arity) {
                    self.runtimeError("Expected {d} arguments but got {d}", .{callee.arity, argCount});
                    return InterpreterError.RuntimeError;
                }
                if (self.frameCount == callstack_size - 1)
                    return InterpreterError.StackOverflow;
                self.frameCount += 1;
                self.frames[self.frameCount - 1] = CallFrame.init(.Function, callee, self.stackTop - argCount - 1);
            }

            fn callNative(self: *@This(), native: *Obj.Native, argCount: u8) !void {
                if (argCount < native.arity_min or argCount > native.arity_max) {
                    self.runtimeError("Expected from {d} to {d} arguments but got {d}", .{native.arity_min, native.arity_max, argCount});
                    return InterpreterError.RuntimeError;
                }
                const result = try native.call(&self.vm.objects, argCount, self.stackTop - argCount);
                self.stackTop -= argCount + 1;
                self.push(result);
                return;
            }

            fn captureUpvalue(self: *@This(), slot: u8) !*Obj.Upvalue {
                var upvalue = self.open_upvalues.tip;
                while(upvalue) |el| : (upvalue = el.next) {
                    const val = el.val.?;
                    if (val.slot == slot)
                        return val;
                    if (val.slot > slot)
                        break;
                }
                const new = try self.vm.objects.emplace(.Upvalue, .{.val = &self.frame().slots[slot], .slot = slot});
                try self.open_upvalues.insert_after(upvalue, new);
                return new;
            }

            fn closeUpvalues(self: *@This(), slot: u8) !void {
                while(self.open_upvalues.tip) |el| {
                    if (el.val.?.slot < slot) break;

                    const upval = self.open_upvalues.pop() catch unreachable;
                    try upval.close(self.vm.allocator);
                }
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
                return @intFromPtr(self.ip()) - @intFromPtr(self.frame().chunk.code.data.ptr);
            }

            fn current_slot(self: *const @This()) u8 {
                return @intCast((@intFromPtr(self.stackTop) - @intFromPtr(self.frame().slots)) / @sizeOf(@TypeOf(self.stackTop[0])));
            }

            fn execute(self: *@This(), dbg: bool) !void {
                while (true) {
                    if (dbg) {
                        std.debug.print("          ", .{});
                        var stackPtr: [*]Value = &self.stack;
                        while (stackPtr != self.stackTop) : (stackPtr += 1) {
                            std.debug.print("[{s}]", .{stackPtr[0]});
                        }
                        std.debug.print("\n", .{});
                        _ = try debug.disassembleInstruction(self.frame().chunk, self.instruction_idx());
                    }
                    const instruction: u8 = self.read_byte();
                    switch (instruction) {
                        @intFromEnum(OP.PRINT) => {
                            std.debug.print("{s}\n", .{self.pop()});
                        },
                        @intFromEnum(OP.RETURN) => {
                            const result = self.pop();
                            if (self.frameCount == 1) {
                                _ = self.pop();
                                return;
                            }
                            try self.closeUpvalues(0);
                            self.stackTop = self.frame().slots;
                            self.frameCount -= 1;
                            self.push(result);
                        },
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
                            self.push(self.frame().slots[self.read_byte()]);
                        },
                        @intFromEnum(OP.SET_LOCAL) => {
                            self.frame().slots[self.read_byte()] = self.peek(0);
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
                        @intFromEnum(OP.GET_UPVALUE) => {
                            const closure = try self.frame().callee.cast(.Closure);
                            const index = self.read_byte();
                            self.push(closure.upvalues[index].?.location.*);
                        },
                        @intFromEnum(OP.SET_UPVALUE) => {
                            const closure = try self.frame().callee.cast(.Closure);
                            const index = self.read_byte();
                            closure.upvalues[index].?.location.* = self.peek(0);
                        },
                        @intFromEnum(OP.CLOSE_UPVALUE) => {
                            try self.closeUpvalues(self.current_slot());
                            _ = self.pop();
                        },
                        @intFromEnum(OP.GET_INDEX) => {
                            const key = self.pop();
                            const obj = self.pop();
                            var pushed = false;
                            if (obj.is(Value.obj)) {
                                switch(obj.obj.type) {
                                    .Function, .Native, .Closure, .Upvalue => {},
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
                            var pushed = false;
                            if (obj.is(Value.obj)) {
                                switch(obj.obj.type) {
                                    .Function, .Native, .Closure, .Upvalue, .String => {},
                                    inline else => |tp| {
                                        var m = obj.obj.cast(tp) catch unreachable;
                                        if (val.is(Value.nil)) {
                                            m.delete(key);
                                        } else {
                                            _ = try m.set(key, val);
                                        }
                                        pushed = true;
                                    }
                                }
                            }
                            if (!pushed) {
                                self.runtimeError("Cannot index a value of type {s}", .{obj.typeName()});
                                return InterpreterError.RuntimeError;
                            }
                            self.push(val);
                        },
                        @intFromEnum(OP.CALL) => {
                            const argCount = self.read_byte();
                            try self.callValue(self.peek(argCount), argCount);
                        },
                        @intFromEnum(OP.CLOSURE) => {
                            const function = try self.read_constant().obj.cast(.Function);
                            const closure = try self.vm.objects.emplace(.Closure, function);
                            for(closure.upvalues[0..closure.upvalues_len]) |*upvalue| {
                                const isLocal = self.read_byte();
                                const slot = self.read_byte();
                                if(isLocal == 1) {
                                    upvalue.* = try self.captureUpvalue(slot);
                                } else {
                                    const callee = try self.frame().callee.cast(.Closure);
                                    upvalue.* = callee.upvalues[slot];
                                }
                            }
                            self.push(Value.init(closure.cast()));
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
                var i = self.frameCount - 1;
                while (true) : (i -= 1) {
                    const fram = self.frames[i];
                    const idx = @intFromPtr(fram.ip) - @intFromPtr(fram.chunk.code.data.ptr);
                    std.debug.print("[line {d}] in {s}\n", .{fram.chunk.lines.get(idx) catch 1, fram.callee});
                    if (i == 0) break;
                }
                std.debug.print(fmt ++ "\n", args);
            }
        };
    }

    pub fn deinit(self: *@This()) void {
        self.objects.deinit();
        self.globals.deinit();
    }
};
