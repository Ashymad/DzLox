const std = @import("std");
const scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const Value = @import("value.zig").Value;
const Obj = @import("obj.zig").Obj;
const debug = @import("debug.zig");
const Token = scanner.TokenType;

pub const CompilerError = Obj.Error || scanner.ScannerError || Chunk.Error || Value.ParseNumberError || error{ UnexpectedToken, NotAnExpression };

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
    compilingChunk: Chunk,
    allocator: std.mem.Allocator,
    objects: *Obj.List,

    const Self = @This();

    const ParseFn = *const fn (*Self) void;

    const ParseRule = struct {
        prefix: ?ParseFn,
        infix: ?ParseFn,
        precedence: Precedence,
        pub fn init(prefix: ?ParseFn, infix: ?ParseFn, precedence: Precedence) @This() {
            return @This(){ .prefix = prefix, .infix = infix, .precedence = precedence };
        }
    };

    const rules = init: {
        var new: [@typeInfo(Token).Enum.fields.len]ParseRule = undefined;
        for (&new, 0..) |*v, i| {
            const T = Token;
            const S = Self;
            const R = ParseRule.init;
            const P = Precedence;
            const tok: Token = @enumFromInt(i);
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
                T.STRING        => R(S.string,   null,      P.NONE ),
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

    fn getRule(tok: Token) *const ParseRule {
        return &Compiler.rules[@intFromEnum(tok)];
    }

    fn advance(self: *Self) void {
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

    fn currentChunk(self: *Self) *Chunk {
        return &self.compilingChunk;
    }

    fn emitByte(self: *Self, byte: u8) void {
        self.currentChunk().write(byte, self.previous.line) catch |err| {
            self.lastError = err;
            self.errorAtCurrent("Out of Memory");
        };
    }

    fn emitOP(self: *Self, op: OP) void {
        self.currentChunk().writeOP(op, self.previous.line) catch |err| {
            self.lastError = err;
            self.errorAtCurrent("Out of Memory");
        };
    }

    fn emit(self: *Self, op: OP, byte: u8) void {
        self.emitOP(op);
        self.emitByte(byte);
    }

    fn emit2OP(self: *Self, op: OP, op2: OP) void {
        self.emitOP(op);
        self.emitOP(op2);
    }

    fn endCompiler(self: *Self) void {
        self.emitReturn();
    }

    fn emitReturn(self: *Self) void {
        self.emitOP(OP.RETURN);
    }

    fn errorAtCurrent(self: *Self, message: []const u8) void {
        self.errorAt(self.current, message);
    }

    fn errorAtPrevious(self: *Self, message: []const u8) void {
        self.errorAt(self.previous, message);
    }

    fn expression(self: *Self) void {
        self.parsePrecedence(Precedence.ASSIGNMENT);
    }

    fn parsePrecedence(self: *Self, precedence: Precedence) void {
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

    fn errorAt(self: *Self, token: scanner.Token, message: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;
        std.debug.print("[{d}:{d}] Error", .{ token.line, token.column });
        if (token.type) |tpe| {
            if (tpe == Token.EOF) {
                std.debug.print(" at end", .{});
            } else {
                std.debug.print(" at {s}", .{token.lexeme});
            }
        } else |_| {}
        std.debug.print(": {s}\n", .{message});
        self.hadError = true;
    }

    fn consume(self: *Self, tok: Token, message: []const u8) void {
        if (self.current.type) |tpe| {
            if (tpe == tok) {
                self.advance();
                return;
            }
        } else |_| {}
        self.lastError = CompilerError.UnexpectedToken;
        self.errorAtCurrent(message);
    }

    fn number(self: *Self) void {
        self.emitConstant(Value.parseNumber(self.previous.lexeme) catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Invalid numeric literal");
            return;
        });
    }

    fn string(self: *Self) void {
        self.emitConstant(Value.init(self.objects.emplace(.String, &.{self.previous.lexeme[1 .. self.previous.lexeme.len - 1]}) catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Couldn't allocate object");
            return;
        }));
    }

    fn emitConstant(self: *Self, val: Value) void {
        self.emit(OP.CONSTANT, self.makeConstant(val));
    }

    fn makeConstant(self: *Self, val: Value) u8 {
        return self.currentChunk().addConstant(val) catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Too many constants in one chunk");
            return 0;
        };
    }

    fn grouping(self: *Self) void {
        self.expression();
        self.consume(Token.RIGHT_PAREN, "Expected ')' after expression");
    }

    fn unary(self: *Self) void {
        const operatorType = self.previous.type catch unreachable;

        self.parsePrecedence(Precedence.UNARY);

        switch (operatorType) {
            Token.MINUS => self.emitOP(OP.NEGATE),
            Token.BANG => self.emitOP(OP.NOT),
            else => unreachable,
        }
    }

    fn literal(self: *Self) void {
        switch (self.previous.type catch unreachable) {
            Token.FALSE => self.emitOP(OP.FALSE),
            Token.TRUE => self.emitOP(OP.TRUE),
            Token.NIL => self.emitOP(OP.NIL),
            else => unreachable,
        }
    }

    fn binary(self: *Self) void {
        const operatorType = self.previous.type catch unreachable;
        self.parsePrecedence(getRule(operatorType).precedence.inc());

        switch (operatorType) {
            Token.PLUS => self.emitOP(OP.ADD),
            Token.MINUS => self.emitOP(OP.SUBTRACT),
            Token.STAR => self.emitOP(OP.MULTIPLY),
            Token.SLASH => self.emitOP(OP.DIVIDE),
            Token.BANG_EQUAL => self.emit2OP(OP.EQUAL, OP.NOT),
            Token.EQUAL_EQUAL => self.emitOP(OP.EQUAL),
            Token.GREATER => self.emitOP(OP.GREATER),
            Token.GREATER_EQUAL => self.emit2OP(OP.LESS, OP.NOT),
            Token.LESS => self.emitOP(OP.LESS),
            Token.LESS_EQUAL => self.emit2OP(OP.GREATER, OP.NOT),
            else => unreachable,
        }
    }

    fn ternary(self: *Self) void {
        const operatorType = self.previous.type catch unreachable;
        self.parsePrecedence(getRule(operatorType).precedence.inc());

        // emit bytecode

        self.consume(Token.COLON, "Expected ':' in ternary expression.");

        self.parsePrecedence(getRule(operatorType).precedence.inc());

        // emit bytecode
    }

    fn declaration(self: *Self) void {
        if (self.match(Token.VAR)) {
            self.varDeclaration();
        } else {
            self.statement();
        }

        if (self.panicMode) self.synchronize();
    }

    fn varDeclaration(self: *Self) void {
        const global = self.parseVariable("Expect variable name.") catch |err| {
            self.lastError = err;
            self.errorAtPrevious("Couldn't create variable");
            return;
        };

        if (self.match(Token.EQUAL)) {
            self.expression();
        } else {
            self.emitOP(OP.NIL);
        }

        self.consume(Token.SEMICOLON, "Expect ';' after variable declaration.");

        self.defineVariable(global);
    }

    fn parseVariable(self: *Self, errorMessage: []const u8) !u8 {
        self.consume(Token.IDENTIFIER, errorMessage);
        return try self.identifierConstant(self.previous);
    }

    fn identifierConstant(self: *Self, tok: scanner.Token) !u8 {
        return self.makeConstant(Value.init(try self.objects.emplace(.String, &.{tok.lexeme})));
    }

    fn defineVariable(self: *Self, global: u8) void {
        self.emit(OP.DEFINE_GLOBAL, global);
    }

    fn synchronize(self: *Self) void {
        self.panicMode = false;

        while ((self.current.type catch Token.NIL) != Token.EOF) {
            if ((self.previous.type catch Token.NIL) == Token.SEMICOLON) return;
            switch (self.current.type catch Token.NIL) {
                Token.CLASS, Token.FUN, Token.VAR, Token.IF, Token.FOR, Token.WHILE, Token.PRINT, Token.RETURN => return,
                else => self.advance(),
            }
        }
    }

    fn statement(self: *Self) void {
        if (self.match(Token.PRINT)) {
            self.printStatement();
        } else {
            self.expressionStatement();
        }
    }

    fn expressionStatement(self: *Self) void {
        self.expression();
        self.consume(Token.SEMICOLON, "Expect ';' after expression.");
        self.emitOP(OP.POP);
    }

    fn match(self: *Self, token: Token) bool {
        if (!self.check(token)) return false;
        self.advance();
        return true;
    }

    fn check(self: *const Self, token: Token) bool {
        return if (self.current.type) |tp| tp == token else |_| false;
    }

    fn printStatement(self: *Self) void {
        self.expression();
        self.consume(Token.SEMICOLON, "Expect ';' after value.");
        self.emitOP(OP.PRINT);
    }

    pub fn compile(source: []const u8, objects: *Obj.List, allocator: std.mem.Allocator) CompilerError!Chunk {
        // zig fmt: off
        var self = Self{
            .scanner = try scanner.Scanner.init(source),
            .current = scanner.Token.Empty,
            .previous = scanner.Token.Empty,
            .panicMode = false,
            .hadError = false,
            .lastError = scanner.ScannerError.EmptyToken,
            .compilingChunk = try Chunk.init(allocator),
            .allocator = allocator,
            .objects = objects
        };
        // zig fmt: on
        errdefer self.compilingChunk.deinit();

        self.advance();
        while (!self.match(Token.EOF)) {
            self.declaration();
        }
        self.endCompiler();

        return if (self.hadError) self.lastError else self.compilingChunk;
    }
};
