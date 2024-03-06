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

pub const ScannerError = error{ UnexpectedCharacter, UnknownCharacter, UnterminatedString, EmptyToken };

pub fn ScannerErrorString(err: ScannerError) []const u8 {
    return switch (err) {
        ScannerError.UnknownCharacter => "Unknown Character",
        ScannerError.UnexpectedCharacter => "Unexpected Character",
        ScannerError.UnterminatedString => "Unterminated String",
        ScannerError.EmptyToken => "Empty Token",
    };
}

pub const Token = struct {
    type: ScannerError!TokenType,
    lexeme: []const u8,
    line: i32,
    column: usize,

    pub const Empty = @This(){ .type = ScannerError.EmptyToken, .lexeme = "", .line = -1, .column = 0 };
};

pub const Scanner = struct {
    const identifiers = trie.TrieTable(TokenType, .{
        .{ "and", TokenType.AND },
        .{ "class", TokenType.CLASS },
        .{ "else", TokenType.ELSE },
        .{ "false", TokenType.FALSE },
        .{ "for", TokenType.FOR },
        .{ "fun", TokenType.FUN },
        .{ "if", TokenType.IF },
        .{ "nil", TokenType.NIL },
        .{ "or", TokenType.OR },
        .{ "print", TokenType.PRINT },
        .{ "return", TokenType.RETURN },
        .{ "super", TokenType.SUPER },
        .{ "this", TokenType.THIS },
        .{ "true", TokenType.TRUE },
        .{ "var", TokenType.VAR },
        .{ "while", TokenType.WHILE },
    });

    pub fn init(source: []const u8) !@This() {
        return @This(){ .start = source.ptr, .current = source.ptr, .end = source.ptr + source.len, .line_ptr = source.ptr, .line = 0 };
    }

    pub fn scanToken(self: *@This()) Token {
        self.skipWhitespace();

        self.start = self.current;

        if (self.isAtEnd()) return self.makeToken(TokenType.EOF);

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
            else => return self.makeToken(ScannerError.UnknownCharacter),
        }

        return self.makeToken(ScannerError.UnexpectedCharacter);
    }

    fn string(self: *@This()) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) return self.makeToken(ScannerError.UnterminatedString);

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
                    self.line_ptr = self.current;
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
        if (identifiers.get(self.lexeme())) |tok| {
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

    fn makeToken(self: *const @This(), tokentype: ScannerError!TokenType) Token {
        return Token{ .type = tokentype, .lexeme = self.lexeme(), .line = self.line, .column = self.column() };
    }

    fn lexeme_len(self: *const @This()) usize {
        return @intFromPtr(self.current) - @intFromPtr(self.start);
    }

    fn column(self: *const @This()) usize {
        return @intFromPtr(self.start) - @intFromPtr(self.line_ptr);
    }

    fn lexeme(self: *const @This()) []const u8 {
        return self.start[0..self.lexeme_len()];
    }

    start: [*]const u8,
    current: [*]const u8,
    end: [*]const u8,
    line_ptr: [*]const u8,
    line: i32,
};
