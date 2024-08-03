const std = @import("std");
const scanner = @import("scanner.zig");
const Chunk = @import("chunk.zig").Chunk;
const OP = @import("chunk.zig").OP;
const Value = @import("value.zig").Value;
const ValueArray = @import("value.zig").ValueArray;
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


pub fn Compiler(size: comptime_int) type {
    return struct {
        current: scanner.Token,
        previous: scanner.Token,
        scanner: scanner.Scanner,
        lastError: CompilerError,
        hadError: bool,
        panicMode: bool,
        compilingChunk: Chunk,
        allocator: std.mem.Allocator,
        objects: *Obj.List,
        locals: [size]Local,
        localCount: usize,
        scopeDepth: usize,

        const Self = @This();

        const Local = struct {
            name: scanner.Token,
            depth: ?usize,
            con: bool,
        };

        const ParseFn = *const fn (*Self, bool) void;

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
                    T.LEFT_BRACE    => R(null,      null,      P.NONE ),
                    T.RIGHT_BRACE   => R(null,       null,      P.NONE ),
                    T.LEFT_BRACKET  => R(S.map,       null,      P.NONE ),
                    T.RIGHT_BRACKET => R(null,       null,      P.NONE ),
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
                    T.IDENTIFIER    => R(S.variable, null,      P.NONE ),
                    T.STRING        => R(S.string,   null,      P.NONE ),
                    T.NUMBER        => R(S.number,   null,      P.NONE ),
                    T.AND           => R(null,       S._and,    P.AND ),
                    T.CLASS         => R(null,       null,      P.NONE ),
                    T.ELSE          => R(null,       null,      P.NONE ),
                    T.FALSE         => R(S.literal,  null,      P.NONE ),
                    T.FOR           => R(null,       null,      P.NONE ),
                    T.FUN           => R(null,       null,      P.NONE ),
                    T.IF            => R(null,       null,      P.NONE ),
                    T.NIL           => R(S.literal,  null,      P.NONE ),
                    T.OR            => R(null,       S._or,     P.OR ),
                    T.PRINT         => R(null,       null,      P.NONE ),
                    T.RETURN        => R(null,       null,      P.NONE ),
                    T.SUPER         => R(null,       null,      P.NONE ),
                    T.THIS          => R(null,       null,      P.NONE ),
                    T.TRUE          => R(S.literal,  null,      P.NONE ),
                    T.VAR           => R(null,       null,      P.NONE ),
                    T.CON           => R(null,       null,      P.NONE ),
                    T.WHILE         => R(null,       null,      P.NONE ),
                    T.EOF           => R(null,       null,      P.NONE ),
                    // zig fmt: on
                };
            }
            break :init new;
        };

        fn getRule(tok: Token) *const ParseRule {
            return &Self.rules[@intFromEnum(tok)];
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
            const canAssign = precedence.lessOrEq(Precedence.ASSIGNMENT);

            self.advance();
            if (getRule(self.previous.type catch unreachable).prefix) |prefixRule| {
                prefixRule(self, canAssign);
            } else {
                self.lastError = CompilerError.NotAnExpression;
                self.errorAtPrevious("Expect expression.");
                return;
            }

            while (precedence.lessOrEq(getRule(self.current.type catch unreachable).precedence)) {
                self.advance();
                if (getRule(self.previous.type catch unreachable).infix) |infixRule| {
                    infixRule(self, canAssign);
                } else {
                    self.lastError = CompilerError.NotAnExpression;
                    self.errorAtPrevious("Expect expression.");
                    return;
                }
            }

            if (canAssign and self.match(Token.EQUAL)) {
                self.errorAtPrevious("Invalid assignment target.");
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

        fn number(self: *Self, _: bool) void {
            self.emitConstant(Value.parseNumber(self.previous.lexeme) catch |err| {
                self.lastError = err;
                self.errorAtPrevious("Invalid numeric literal");
                return;
            });
        }

        fn string(self: *Self, _: bool) void {
            self.emitConstant(Value.init(self.objects.emplace(.String, &.{self.previous.lexeme[1 .. self.previous.lexeme.len - 1]}) catch |err| {
                self.lastError = err;
                self.errorAtPrevious("Couldn't allocate object");
                return;
            }));
        }

        fn parseLiteralValue(self: *Self) CompilerError!Value {
            if (self.match(Token.STRING)) {
                return Value.init(try self.objects.emplace(.String, &.{self.previous.lexeme[1 .. self.previous.lexeme.len - 1]}));
            } else if (self.match(Token.NUMBER)) {
                return try Value.parseNumber(self.previous.lexeme);
            } else if (self.match(Token.FALSE)) {
                return Value.init(false);
            } else if (self.match(Token.TRUE)) {
                return Value.init(true);
            } else if (self.match(Token.NIL)) {
                return Value.init({});
            } else if (self.match(Token.LEFT_BRACKET)) {
                return self.parseLiteralMap();
            } else {
                self.errorAtCurrent("Map initalizer can only contain literals");
                return error.UnexpectedToken;
            }
        }

        fn parseLiteralMap(self: *Self) CompilerError!Value {
            var array = try ValueArray.init(self.allocator);
            defer array.deinit();
            while (!self.match(Token.RIGHT_BRACKET)) {
                try array.add(try self.parseLiteralValue());
                self.consume(Token.COLON, "Expect ':' after key in map initalizer");
                try array.add(try self.parseLiteralValue());
                if (self.match(Token.RIGHT_BRACKET))
                    break;
                self.consume(Token.COMMA, "Expect ',' after value in map initalizer");
            }
            return Value.init(try self.objects.emplace(.Map, array));
        }

        fn map(self: *Self, _: bool) void {
            self.emitConstant(self.parseLiteralMap() catch |err| {
                self.lastError = err;
                return;
            });
        }

        fn variable(self: *Self, canAssign: bool) void {
            self.namedVariable(self.previous, canAssign);
        }

        fn namedVariable(self: *Self, tok: scanner.Token, canAssign: bool) void {
            var getOP = OP.GET_LOCAL;
            var setOP = OP.SET_LOCAL;
            const arg = self.resolveLocal(tok) catch blk: {
                getOP = OP.GET_GLOBAL;
                setOP = OP.SET_GLOBAL;
                break :blk self.identifierConstant(tok) catch return;
            };

            if (canAssign and self.match(Token.EQUAL)) {
                if(setOP == OP.SET_LOCAL and self.locals[arg].con) {
                    self.errorAtPrevious("Cannot assign to a constant");
                    return;
                }
                self.expression();
                self.emit(setOP, arg);
            } else {
                self.emit(getOP, arg);
            }
        }

        fn resolveLocal(self: *Self, name: scanner.Token) !u8 {
            var i = self.localCount;
            while (i > 0) : (i -= 1) {
                if(self.locals[i-1].depth) |_| {
                    if (identifiersEql(self.locals[i-1].name, name)) {
                        return @intCast(i-1);
                    }
                } else {
                    self.errorAt(name, "Can't read local variable in it's own initializer");
                }
            }
            return error.NotFound;
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

        fn grouping(self: *Self, _: bool) void {
            self.expression();
            self.consume(Token.RIGHT_PAREN, "Expected ')' after expression");
        }

        fn _and(self: *Self, _: bool) void {
            const endJump = self.emitJump(OP.JUMP_IF_FALSE);

            self.emitOP(OP.POP);
            self.parsePrecedence(Precedence.AND);
            self.patchJump(endJump);
        }

        fn _or(self: *Self, _: bool) void {
            const elseJump = self.emitJump(OP.JUMP_IF_FALSE);
            const endJump = self.emitJump(OP.JUMP);

            self.patchJump(elseJump);
            self.emitOP(OP.POP);
            self.parsePrecedence(Precedence.OR);
            self.patchJump(endJump);
        }

        fn unary(self: *Self, _: bool) void {
            const operatorType = self.previous.type catch unreachable;

            self.parsePrecedence(Precedence.UNARY);

            switch (operatorType) {
                Token.MINUS => self.emitOP(OP.NEGATE),
                Token.BANG => self.emitOP(OP.NOT),
                else => unreachable,
            }
        }

        fn literal(self: *Self, _: bool) void {
            switch (self.previous.type catch unreachable) {
                Token.FALSE => self.emitOP(OP.FALSE),
                Token.TRUE => self.emitOP(OP.TRUE),
                Token.NIL => self.emitOP(OP.NIL),
                else => unreachable,
            }
        }

        fn binary(self: *Self, _: bool) void {
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

        fn ternary(self: *Self, _: bool) void {
            const operatorType = self.previous.type catch unreachable;

            const thenJump = self.emitJump(OP.JUMP_IF_FALSE);
            self.emitOP(OP.POP);
            self.parsePrecedence(getRule(operatorType).precedence.inc());
            const elseJump = self.emitJump(OP.JUMP);
            self.patchJump(thenJump);

            self.consume(Token.COLON, "Expected ':' in ternary expression.");

            self.emitOP(OP.POP);
            self.parsePrecedence(getRule(operatorType).precedence.inc());
            self.patchJump(elseJump);
        }

        fn declaration(self: *Self) void {
            if (self.match(Token.VAR)) {
                self.varDeclaration();
            } else if (self.match(Token.CON)) {
                self.conDeclaration();
            } else {
                self.statement();
            }

            if (self.panicMode) self.synchronize();
        }

        fn varDeclaration(self: *Self) void {
            const global = self.parseVariable("Expect variable name.", false) catch return;

            if (self.match(Token.EQUAL)) {
                self.expression();
            } else {
                self.emitOP(OP.NIL);
            }

            self.consume(Token.SEMICOLON, "Expect ';' after variable declaration.");

            self.defineVariable(global, false);
        }

        fn conDeclaration(self: *Self) void {
            const global = self.parseVariable("Expect variable name.", true) catch return;

            self.consume(Token.EQUAL, "Constant variable has to be initialized.");

            self.expression();

            self.consume(Token.SEMICOLON, "Expect ';' after variable declaration.");

            self.defineVariable(global, true);
        }

        fn parseVariable(self: *Self, errorMessage: []const u8, con: bool) !u8 {
            self.consume(Token.IDENTIFIER, errorMessage);

            self.declareVariable(con);
            if(self.scopeDepth > 0) return 0;

            return self.identifierConstant(self.previous);
        }

        fn identifierConstant(self: *Self, tok: scanner.Token) !u8 {
            return self.makeConstant(Value.init(self.objects.emplace(.String, &.{tok.lexeme}) catch |err| {
                self.lastError = err;
                self.errorAtPrevious("Couldn't allocate identifier");
                return err;
            }));
        }

        fn declareVariable(self: *Self, con: bool) void {
            if (self.scopeDepth == 0) return;

            var i = self.localCount;
            while (i > 0) : (i -= 1) {
                const local = self.locals[i-1];
                if (local.depth) |depth| {
                    if (depth < self.scopeDepth) break;
                }

                if (identifiersEql(local.name, self.previous)) {
                    self.errorAtPrevious("Already a variable with this name in this scope.");
                }
            }

            self.addLocal(self.previous, con);
        }

        fn identifiersEql(a: scanner.Token, b: scanner.Token) bool {
            return std.mem.eql(u8, a.lexeme, b.lexeme);
        }

        fn addLocal(self: *Self, name: scanner.Token, con: bool) void {
            if (self.localCount == size) {
                self.errorAt(name, "Too many variables in function");
                return;
            }
            self.locals[self.localCount] = Local {.name = name, .depth = null, .con = con};
            self.localCount += 1;
        }

        fn markInitialized(self: *Self) void {
            self.locals[self.localCount-1].depth = self.scopeDepth;
        }

        fn defineVariable(self: *Self, global: u8, con: bool) void {
            if (self.scopeDepth > 0){
                self.markInitialized();
                return;
            }

            if (con) {
                self.emit(OP.DEFINE_GLOBAL_CONSTANT, global);
            } else {
                self.emit(OP.DEFINE_GLOBAL, global);
            }
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
            } else if (self.match(Token.IF)) {
                self.ifStatement();
            } else if (self.match(Token.WHILE)) {
                self.whileStatement();
            } else if (self.match(Token.FOR)) {
                self.forStatement();
            } else if (self.match(Token.LEFT_BRACE)) {
                self.beginScope();
                self.block();
                self.endScope();
            } else {
                self.expressionStatement();
            }
        }

        fn whileStatement(self: *Self) void {
            const loopStart = self.currentChunk().code.len;

            self.consume(Token.LEFT_PAREN, "Expect '(' after 'while'.");
            self.expression();
            self.consume(Token.RIGHT_PAREN, "Expect ')' after condition");

            const exitJump = self.emitJump(OP.JUMP_IF_FALSE);
            self.emitOP(OP.POP);
            self.statement();
            self.emitLoop(loopStart);

            self.patchJump(exitJump);
            self.emitOP(OP.POP);
        }

        fn forStatement(self: *Self) void {
            self.beginScope();
            self.consume(Token.LEFT_PAREN, "Expect '(' after 'for'.");

            if (self.match(Token.SEMICOLON)) {
                // Empty initializer
            } else if (self.match(Token.VAR)) {
                self.varDeclaration();
            } else if (self.match(Token.CON)) {
                self.conDeclaration();
            } else {
                self.expressionStatement();
            }

            var loopStart = self.currentChunk().code.len;

            var exitJump: ?usize = null;
            if (!self.match(Token.SEMICOLON)) {
                self.expression();
                self.consume(Token.SEMICOLON, "Expect ';' after condition clause");

                exitJump = self.emitJump(OP.JUMP_IF_FALSE);
                self.emitOP(OP.POP);
            }

            if (!self.match(Token.RIGHT_PAREN)) {
                const bodyJump = self.emitJump(OP.JUMP);
                const incrementStart = self.currentChunk().code.len;
                self.expression();
                self.emitOP(OP.POP);
                self.consume(Token.RIGHT_PAREN, "Expect ')' after increment clause");

                self.emitLoop(loopStart);
                loopStart = incrementStart;
                self.patchJump(bodyJump);
            }

            self.statement();
            self.emitLoop(loopStart);

            if (exitJump) |jump| {
                self.patchJump(jump);
                self.emitOP(OP.POP);
            }
            self.endScope();
        }

        fn emitLoop(self: *Self, start: usize) void {
            self.emitOP(OP.LOOP);
            const offset = self.currentChunk().code.len - start + 2;

            if (offset > std.math.maxInt(u16)) {
                self.errorAtPrevious("Loop body too large");
                return;
            }

            self.emitByte(@intCast((offset >> 8) & 0xff));
            self.emitByte(@intCast(offset & 0xff));
        }

        fn ifStatement(self: *Self) void {
            self.consume(Token.LEFT_PAREN, "Expect '(' after 'if'.");
            self.expression();
            self.consume(Token.RIGHT_PAREN, "Expect ')' after condition");

            const thenJump = self.emitJump(OP.JUMP_IF_FALSE);
            self.emitOP(OP.POP);
            self.statement();
            const elseJump = self.emitJump(OP.JUMP);
            self.patchJump(thenJump);
            self.emitOP(OP.POP);
            if (self.match(Token.ELSE)) self.statement();
            self.patchJump(elseJump);
        }

        fn emitJump(self: *Self, instruction: OP) usize {
            self.emitOP(instruction);
            self.emitByte(0xff);
            self.emitByte(0xff);
            return self.currentChunk().code.len - 2;
        }

        fn patchJump(self: *Self, offset: usize) void {
            const jump = self.currentChunk().code.len - offset - 2;
            if (jump > std.math.maxInt(u16)) {
                self.errorAtPrevious("Jump too large");
                return;
            }

            self.currentChunk().code.set(offset, @intCast((jump >> 8) & 0xff)) catch {
                self.errorAtPrevious("Invalid jump offset");
            };
            self.currentChunk().code.set(offset + 1, @intCast(jump & 0xff)) catch {
                self.errorAtPrevious("Invalid jump offset");
            };

        }

        fn block(self: *Self) void {
            while(!self.check(Token.RIGHT_BRACE) and !self.check(Token.EOF)) {
                self.declaration();
            }

            self.consume(Token.RIGHT_BRACE, "Expect '}' after block.");
        }

        fn beginScope(self: *Self) void {
            self.scopeDepth += 1;
        }

        fn endScope(self: *Self) void {
            self.scopeDepth -= 1;

            while(self.localCount > 0) {
                if (self.locals[self.localCount-1].depth) |depth| {
                    if (depth <= self.scopeDepth) break;
                } else {
                    self.errorAt(self.locals[self.localCount-1].name, "Unitialized variable at scope end");
                }
                self.emitOP(OP.POP);
                self.localCount -= 1;
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
                .objects = objects,
                .locals = [_]Local{Local{.name = scanner.Token.Empty, .depth = 0, .con = true}} ** size,
                .localCount = 0,
                .scopeDepth = 0,
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
}
