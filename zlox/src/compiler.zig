const std = @import("std");
const scanner = @import("scanner.zig");
const chunk = @import("chunk.zig");
const value = @import("value.zig");
const debug = @import("debug.zig");

pub const CompilerError = scanner.ScannerError || chunk.ChunkError || value.ParseValueError || error{ UnexpectedToken, NotAnExpression };

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
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

    const ParseRule = struct { prefix: ?ParseFn, infix: ?ParseFn, precedence: Precedence };

    const rules = init: {
        var new: [@typeInfo(scanner.TokenType).Enum.fields.len]ParseRule = undefined;
        for (&new, 0..) |*v, i| {
            const tok: scanner.TokenType = @enumFromInt(i);
            const T = scanner.TokenType;
            v.* = switch (tok) {
                // zig fmt: off
                T.LEFT_PAREN    => ParseRule{ .prefix = @This().grouping, .infix = null,           .precedence = Precedence.NONE },
                T.RIGHT_PAREN   => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.LEFT_BRACE    => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.RIGHT_BRACE   => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.COMMA         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.DOT           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.MINUS         => ParseRule{ .prefix = @This().unary,    .infix = @This().binary, .precedence = Precedence.TERM },
                T.PLUS          => ParseRule{ .prefix = null,             .infix = @This().binary, .precedence = Precedence.TERM },
                T.SEMICOLON     => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.SLASH         => ParseRule{ .prefix = null,             .infix = @This().binary, .precedence = Precedence.FACTOR },
                T.STAR          => ParseRule{ .prefix = null,             .infix = @This().binary, .precedence = Precedence.FACTOR },
                T.BANG          => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.BANG_EQUAL    => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.EQUAL         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.EQUAL_EQUAL   => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.GREATER       => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.GREATER_EQUAL => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.LESS          => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.LESS_EQUAL    => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.IDENTIFIER    => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.STRING        => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.NUMBER        => ParseRule{ .prefix = @This().number,   .infix = null,           .precedence = Precedence.NONE },
                T.AND           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.CLASS         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.ELSE          => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.FALSE         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.FOR           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.FUN           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.IF            => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.NIL           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.OR            => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.PRINT         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.RETURN        => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.SUPER         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.THIS          => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.TRUE          => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.VAR           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.WHILE         => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
                T.EOF           => ParseRule{ .prefix = null,             .infix = null,           .precedence = Precedence.NONE },
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
        self.emitConstant(value.parseValue(self.previous.lexeme) catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Invalid numeric literal");
            return;
        });
    }

    fn emitConstant(self: *@This(), val: value.Value) void {
        self.emit(chunk.OP.CONSTANT, self.makeConstant(val));
    }

    fn makeConstant(self: *@This(), val: value.Value) u8 {
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
            else => unreachable,
        }
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
