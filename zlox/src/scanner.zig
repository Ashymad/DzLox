const std = @import("std");
const trie = @import("trie.zig");

pub const TokenType = enum {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    EOF,
};

pub const ScannerError = error{ UnexpectedCharacter, UnknownCharacter, UnterminatedString };

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: i32,
};

pub const Scanner = struct {
    pub fn init(source: []const u8, allocator: std.mem.Allocator) !@This() {
        var this = @This(){ .start = source.ptr, .current = source.ptr, .end = source.ptr + source.len, .line = 0, .identifiers = try trie.TrieTable(TokenType).init(allocator) };
        try this.identifiers.put("and", TokenType.AND);
        try this.identifiers.put("class", TokenType.CLASS);
        try this.identifiers.put("else", TokenType.ELSE);
        try this.identifiers.put("false", TokenType.FALSE);
        try this.identifiers.put("for", TokenType.FOR);
        try this.identifiers.put("fun", TokenType.FUN);
        try this.identifiers.put("if", TokenType.IF);
        try this.identifiers.put("nil", TokenType.NIL);
        try this.identifiers.put("or", TokenType.OR);
        try this.identifiers.put("print", TokenType.PRINT);
        try this.identifiers.put("return", TokenType.RETURN);
        try this.identifiers.put("super", TokenType.SUPER);
        try this.identifiers.put("this", TokenType.THIS);
        try this.identifiers.put("true", TokenType.TRUE);
        try this.identifiers.put("var", TokenType.VAR);
        try this.identifiers.put("while", TokenType.WHILE);
        return this;
    }

    pub fn deinit(self: *@This()) void {
        self.identifiers.deinit();
    }

    pub fn scanToken(self: *@This()) ScannerError!Token {
        self.start = self.current;

        if (self.isAtEnd()) return self.makeToken(TokenType.EOF);

        self.skipWhitespace();

        switch (self.advance()) {
            '(' => return self.makeToken(TokenType.LEFT_PAREN),
            ')' => return self.makeToken(TokenType.RIGHT_PAREN),
            '{' => return self.makeToken(TokenType.LEFT_BRACE),
            '}' => return self.makeToken(TokenType.RIGHT_BRACE),
            ';' => return self.makeToken(TokenType.SEMICOLON),
            ',' => return self.makeToken(TokenType.COMMA),
            '.' => return self.makeToken(TokenType.DOT),
            '-' => return self.makeToken(TokenType.MINUS),
            '+' => return self.makeToken(TokenType.PLUS),
            '/' => return self.makeToken(TokenType.SLASH),
            '*' => return self.makeToken(TokenType.STAR),
            '!' => return self.makeToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
            '=' => return self.makeToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
            '<' => return self.makeToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
            '>' => return self.makeToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
            '"' => return self.string(),
            '0'...'9' => return self.number(),
            'a'...'z', 'A'...'Z', '_' => return self.identifier(),
            else => return ScannerError.UnknownCharacter,
        }

        return ScannerError.UnexpectedCharacter;
    }

    fn string(self: *@This()) ScannerError!Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) return ScannerError.UnterminatedString;

        _ = self.advance();

        return self.makeToken(TokenType.STRING);
    }

    fn skipWhitespace(self: *@This()) void {
        while (true) {
            switch (self.peek()) {
                ' ', '\r', '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                    } else return;
                },
                else => return,
            }
        }
    }

    fn number(self: *@This()) Token {
        while (isDigit(self.peek())) _ = self.advance();

        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance();
            while (isDigit(self.peek())) _ = self.advance();
        }

        return self.makeToken(TokenType.NUMBER);
    }

    fn identifier(self: *@This()) Token {
        while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();
        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: *const @This()) TokenType {
        if (self.identifiers.get(self.start[0..(@intFromPtr(self.current) - @intFromPtr(self.start))])) |tok| {
            return tok;
        } else {
            return TokenType.IDENTIFIER;
        }
    }

    fn advance(self: *@This()) u8 {
        self.current += 1;
        return (self.current - 1)[0];
    }

    fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn peek(self: *const @This()) u8 {
        return self.current[0];
    }

    fn peekNext(self: *const @This()) u8 {
        return if (self.isAtEnd()) return 0 else self.current[1];
    }

    fn match(self: *@This(), expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.current[0] != expected) return false;
        self.current += 1;
        return true;
    }

    fn isAtEnd(self: *const @This()) bool {
        return self.current == self.end;
    }

    fn makeToken(self: *const @This(), tokentype: TokenType) Token {
        return Token{ .type = tokentype, .lexeme = self.start[0..(@intFromPtr(self.current) - @intFromPtr(self.start))], .line = self.line };
    }

    identifiers: trie.TrieTable(TokenType),
    start: [*]const u8,
    current: [*]const u8,
    end: [*]const u8,
    line: i32,
};
