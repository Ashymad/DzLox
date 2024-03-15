import tokentype;

static immutable TokenType[const(char)[]] keywords;

shared static this() {
    with (TokenType) {
        keywords = [
            "and":    AND,
            "class":  CLASS,
            "else":   ELSE,
            "false":  FALSE,
            "for":    FOR,
            "fun":    FUN,
            "if":     IF,
            "nil":    NIL,
            "or":     OR,
            "print":  PRINT,
            "return": RETURN,
            "super":  SUPER,
            "this":   THIS,
            "true":   TRUE,
            "var":    VAR,
            "while":  WHILE,
            "break":  BREAK,
            "ast":    AST,
        ];
    }
}
