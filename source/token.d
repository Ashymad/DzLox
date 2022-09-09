import tokentype;
import std.conv;
import std.variant;

class Token {
    immutable TokenType type;
    immutable string lexeme;
    const Variant literal;
    immutable int line;

    this(T)(TokenType type, string lexeme, T literal, int line) {
        this.type = type;
        this.lexeme = lexeme;
        this.literal = literal;
        this.line = line;
    }

    void toString(scope void delegate(const(char)[]) sink) const {
        sink(text(type));
        sink(" ");
        sink(lexeme);
        sink(" ");
        sink(text(line));
    }
}
