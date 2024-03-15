const std = @import("std");
const scanner = @import("scanner.zig");
const chunk = @import("chunk.zig");
const Value = @import("value.zig").Value;
const debug = @import("debug.zig");

pub const CompilerError = scanner.ScannerError || chunk.ChunkError || Value.ParseNumberError || error{ UnexpectedToken, NotAnExpression };

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    TERNARY, // ? :
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,

    pub fn inc(self: @This()) @This() {
        return @enumFromInt(@intFromEnum(self) + 1);
    }

    pub fn lessOrEq(self: @This(), rhs: @This()) bool {
        return @intFromEnum(self) <= @intFromEnum(rhs);
    }
};

pub const Compiler = struct {
    current: scanner.Token,
    previous: scanner.Token,
    scanner: scanner.Scanner,
    lastError: CompilerError,
    hadError: bool,
    panicMode: bool,
    compilingChunk: *chunk.Chunk,

    const ParseFn = *const fn (*@This()) void;

    const ParseRule = struct {
        prefix: ?ParseFn,
        infix: ?ParseFn,
        precedence: Precedence,
        pub fn init(prefix: ?ParseFn, infix: ?ParseFn, precedence: Precedence) @This() {
            return @This(){ .prefix = prefix, .infix = infix, .precedence = precedence };
        }
    };

    const rules = init: {
        var new: [@typeInfo(scanner.TokenType).Enum.fields.len]ParseRule = undefined;
        for (&new, 0..) |*v, i| {
            const T = scanner.TokenType;
            const S = @This();
            const R = ParseRule.init;
            const P = Precedence;
            const tok: T = @enumFromInt(i);
            v.* = switch (tok) {
                // zig fmt: off
                T.LEFT_PAREN    => R(S.grouping, null,      P.NONE ),
                T.RIGHT_PAREN   => R(null,       null,      P.NONE ),
                T.LEFT_BRACE    => R(null,       null,      P.NONE ),
                T.RIGHT_BRACE   => R(null,       null,      P.NONE ),
                T.COMMA         => R(null,       null,      P.NONE ),
                T.DOT           => R(null,       null,      P.NONE ),
                T.MINUS         => R(S.unary,    S.binary,  P.TERM ),
                T.PLUS          => R(null,       S.binary,  P.TERM ),
                T.COLON         => R(null,       null,      P.NONE ),
                T.SEMICOLON     => R(null,       null,      P.NONE ),
                T.SLASH         => R(null,       S.binary,  P.FACTOR ),
                T.STAR          => R(null,       S.binary,  P.FACTOR ),
                T.QUESTION      => R(null,       S.ternary, P.TERNARY ),
                T.BANG          => R(S.unary,    null,      P.NONE ),
                T.BANG_EQUAL    => R(null,       S.binary,  P.EQUALITY ),
                T.EQUAL         => R(null,       null,      P.NONE ),
                T.EQUAL_EQUAL   => R(null,       S.binary,  P.EQUALITY ),
                T.GREATER       => R(null,       S.binary,  P.COMPARISON ),
                T.GREATER_EQUAL => R(null,       S.binary,  P.COMPARISON ),
                T.LESS          => R(null,       S.binary,  P.COMPARISON ),
                T.LESS_EQUAL    => R(null,       S.binary,  P.COMPARISON ),
                T.IDENTIFIER    => R(null,       null,      P.NONE ),
                T.STRING        => R(null,       null,      P.NONE ),
                T.NUMBER        => R(S.number,   null,      P.NONE ),
                T.AND           => R(null,       null,      P.NONE ),
                T.CLASS         => R(null,       null,      P.NONE ),
                T.ELSE          => R(null,       null,      P.NONE ),
                T.FALSE         => R(S.literal,  null,      P.NONE ),
                T.FOR           => R(null,       null,      P.NONE ),
                T.FUN           => R(null,       null,      P.NONE ),
                T.IF            => R(null,       null,      P.NONE ),
                T.NIL           => R(S.literal,  null,      P.NONE ),
                T.OR            => R(null,       null,      P.NONE ),
                T.PRINT         => R(null,       null,      P.NONE ),
                T.RETURN        => R(null,       null,      P.NONE ),
                T.SUPER         => R(null,       null,      P.NONE ),
                T.THIS          => R(null,       null,      P.NONE ),
                T.TRUE          => R(S.literal,  null,      P.NONE ),
                T.VAR           => R(null,       null,      P.NONE ),
                T.WHILE         => R(null,       null,      P.NONE ),
                T.EOF           => R(null,       null,      P.NONE ),
                // zig fmt: on
            };
        }
        break :init new;
    };

    fn getRule(tok: scanner.TokenType) *const ParseRule {
        return &Compiler.rules[@intFromEnum(tok)];
    }

    fn advance(self: *@This()) void {
        self.previous = self.current;

        while (true) {
            self.current = self.scanner.scanToken();

            if (self.current.type) |_| {
                break;
            } else |err| {
                self.lastError = err;
                self.errorAtCurrent(scanner.ScannerErrorString(err));
            }
        }
    }

    fn currentChunk(self: *@This()) *chunk.Chunk {
        return self.compilingChunk;
    }

    fn emitByte(self: *@This(), byte: u8) void {
        self.currentChunk().write(byte, self.previous.line) catch |err| {
            self.lastError = err;
            self.errorAtCurrent("Out of Memory");
        };
    }

    fn emitOP(self: *@This(), op: chunk.OP) void {
        self.currentChunk().writeOP(op, self.previous.line) catch |err| {
            self.lastError = err;
            self.errorAtCurrent("Out of Memory");
        };
    }

    fn emit(self: *@This(), op: chunk.OP, byte: u8) void {
        self.emitOP(op);
        self.emitByte(byte);
    }

    fn emit2OP(self: *@This(), op: chunk.OP, op2: chunk.OP) void {
        self.emitOP(op);
        self.emitOP(op2);
    }

    fn endCompiler(self: *@This()) void {
        self.emitReturn();
        if (!self.hadError) {
            debug.disassembleChunk(self.currentChunk().*, "code") catch {
                std.debug.print("Unable to disassemble chunk\n", .{});
            };
        }
    }

    fn emitReturn(self: *@This()) void {
        self.emitOP(chunk.OP.RETURN);
    }

    fn errorAtCurrent(self: *@This(), message: []const u8) void {
        self.errorAt(self.current, message);
    }

    fn errorAtPrevious(self: *@This(), message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn expression(self: *@This()) void {
        self.parsePrecedence(Precedence.ASSIGNMENT);
    }

    fn parsePrecedence(self: *@This(), precedence: Precedence) void {
        self.advance();
        if (getRule(self.previous.type catch unreachable).prefix) |prefixRule| {
            prefixRule(self);
        } else {
            self.lastError = CompilerError.NotAnExpression;
            self.errorAtPrevious("Expect expression.");
            return;
        }

        while (precedence.lessOrEq(getRule(self.current.type catch unreachable).precedence)) {
            self.advance();
            if (getRule(self.previous.type catch unreachable).infix) |infixRule| {
                infixRule(self);
            } else {
                self.lastError = CompilerError.NotAnExpression;
                self.errorAtPrevious("Expect expression.");
                return;
            }
        }
    }

    fn errorAt(self: *@This(), token: scanner.Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;
        std.debug.print("[{d}:{d}] Error", .{ token.line, token.column });
        if (token.type) |tpe| {
            if (tpe == scanner.TokenType.EOF) {
                std.debug.print(" at end", .{});
            } else {
                std.debug.print(" at {s}", .{token.lexeme});
            }
        } else |_| {}
        std.debug.print(": {s}\n", .{message});
        self.hadError = true;
    }

    fn consume(self: *@This(), tok: scanner.TokenType, message: []const u8) void {
        if (self.current.type) |tpe| {
            if (tpe == tok) {
                self.advance();
                return;
            }
        } else |_| {}
        self.lastError = CompilerError.UnexpectedToken;
        self.errorAtCurrent(message);
    }

    fn number(self: *@This()) void {
        self.emitConstant(Value.parseNumber(self.previous.lexeme) catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Invalid numeric literal");
            return;
        });
    }

    fn emitConstant(self: *@This(), val: Value) void {
        self.emit(chunk.OP.CONSTANT, self.makeConstant(val));
    }

    fn makeConstant(self: *@This(), val: Value) u8 {
        return self.currentChunk().addConstant(val) catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Too many constants in one chunk");
            return 0;
        };
    }

    fn grouping(self: *@This()) void {
        self.expression();
        self.consume(scanner.TokenType.RIGHT_PAREN, "Expected ')' after expression");
    }

    fn unary(self: *@This()) void {
        const operatorType = self.previous.type catch unreachable;

        self.parsePrecedence(Precedence.UNARY);

        switch (operatorType) {
            scanner.TokenType.MINUS => self.emitOP(chunk.OP.NEGATE),
            scanner.TokenType.BANG => self.emitOP(chunk.OP.NOT),
            else => unreachable,
        }
    }

    fn literal(self: *@This()) void {
        switch (self.previous.type catch unreachable) {
            scanner.TokenType.FALSE => self.emitOP(chunk.OP.FALSE),
            scanner.TokenType.TRUE => self.emitOP(chunk.OP.TRUE),
            scanner.TokenType.NIL => self.emitOP(chunk.OP.NIL),
            else => unreachable,
        }
    }

    fn binary(self: *@This()) void {
        const operatorType = self.previous.type catch unreachable;
        self.parsePrecedence(getRule(operatorType).precedence.inc());

        switch (operatorType) {
            scanner.TokenType.PLUS => self.emitOP(chunk.OP.ADD),
            scanner.TokenType.MINUS => self.emitOP(chunk.OP.SUBTRACT),
            scanner.TokenType.STAR => self.emitOP(chunk.OP.MULTIPLY),
            scanner.TokenType.SLASH => self.emitOP(chunk.OP.DIVIDE),
            scanner.TokenType.BANG_EQUAL => self.emit2OP(chunk.OP.EQUAL, chunk.OP.NOT),
            scanner.TokenType.EQUAL_EQUAL => self.emitOP(chunk.OP.EQUAL),
            scanner.TokenType.GREATER => self.emitOP(chunk.OP.GREATER),
            scanner.TokenType.GREATER_EQUAL => self.emit2OP(chunk.OP.LESS, chunk.OP.NOT),
            scanner.TokenType.LESS => self.emitOP(chunk.OP.LESS),
            scanner.TokenType.LESS_EQUAL => self.emit2OP(chunk.OP.GREATER, chunk.OP.NOT),
            else => unreachable,
        }
    }

    fn ternary(self: *@This()) void {
        const operatorType = self.previous.type catch unreachable;
        self.parsePrecedence(getRule(operatorType).precedence.inc());

        // emit bytecode

        self.consume(scanner.TokenType.COLON, "Expected ':' in ternary expression.");

        self.parsePrecedence(getRule(operatorType).precedence.inc());

        // emit bytecode
    }

    pub fn compile(source: []const u8, ch: *chunk.Chunk) CompilerError!void {
        var self = @This(){ .scanner = try scanner.Scanner.init(source), .current = scanner.Token.Empty, .previous = scanner.Token.Empty, .panicMode = false, .hadError = false, .lastError = scanner.ScannerError.EmptyToken, .compilingChunk = ch };
        self.advance();
        self.expression();
        self.consume(scanner.TokenType.EOF, "Expected end of expression.");
        self.endCompiler();

        if (self.hadError) return self.lastError;
    }
};
