import tokentype;
import std.conv;
import std.variant;
import std.format;

interface TokenI {
    void toString(scope void delegate(const(char)[]) sink) const;
    static Token!T opCall(T)(TokenType type, string lexeme, T literal, int line) {
        return new Token!T(type, lexeme, literal, line);
    }
    @property Variant literal();
    @property string lexeme() const;
    @property TokenType type() const;
    @property int line() const;
}

class Token(T) : TokenI {
    const TokenType _type;
    const string _lexeme;
    T _literal;
    const int _line;

    this(TokenType type, string lexeme, T literal, int line) {
        _type = type;
        _lexeme = lexeme;
        _literal = literal;
        _line = line;
    }

    void toString(scope void delegate(const(char)[]) sink) const {
        sink(format("Token!(%s)(%s, %s, %s, %s)",
                    T.stringof, _type, _lexeme, _literal, _line));
    }

    @property Variant literal() {
        return Variant(_literal);
    }

    @property string lexeme() const {
        return _lexeme;
    }

    @property TokenType type() const {
        return _type;
    }
    @property int line() const {
        return _line;
    }

}
