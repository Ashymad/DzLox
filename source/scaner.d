import token;
import tokentype;
import std.container;
import std.format;
import std.conv;
import app;

class Scanner {
    private string source;
    private int start = 0;
    private int current = 0;
    private int line = 0;

    private Array!Token tokens;

    this(string source) {
        this.source = source;
        this.tokens = Array!Token();
    }

    this(char[] source) {
        this.source = to!string(source);
        this.tokens = Array!Token();
    }

    Array!Token scanTokens() {
        while (!isAtEnd()) {
            start = current;
            scanToken();
        }
        tokens.insert(new Token(TokenType.EOF, "", null, line));
        return tokens;
    }

    void scanToken() {
        char c = advance();
        with (TokenType) {
            switch (c) {
                case '(': addToken(LEFT_PAREN); break;
                case ')': addToken(RIGHT_PAREN); break;
                case '{': addToken(LEFT_BRACE); break;
                case '}': addToken(RIGHT_BRACE); break;
                case ',': addToken(COMMA); break;
                case '.': addToken(DOT); break;
                case '-': addToken(MINUS); break;
                case '+': addToken(PLUS); break;
                case ';': addToken(SEMICOLON); break;
                case '*': addToken(STAR); break;
                case '!':
                      addToken(match('=') ? BANG_EQUAL : BANG);
                      break;
                case '=':
                      addToken(match('=') ? EQUAL_EQUAL : EQUAL);
                      break;
                case '<':
                      addToken(match('=') ? LESS_EQUAL : LESS);
                      break;
                case '>':
                      addToken(match('=') ? GREATER_EQUAL : GREATER);
                      break;
                case '/':
                      if (match('/')) {
                          // A comment goes until the end of the line.
                          while (peek() != '\n' && !isAtEnd()) advance();
                      } else if (match('*')) {
                          int nest = 1;
                          while (nest > 0) {
                              while ((peek() != '*' || peekNext() != '/') && !isAtEnd()) {
                                  if (peek() == '\n') line++;
                                  if (peek() == '/' && peekNext() == '*') nest++;
                                  advance();
                              }
                              advance();
                              advance();
                              nest--;
                          }
                      } else {
                          addToken(SLASH);
                      }
                      break;
                case '"': stringToken(); break;
                case ' ': 
                case '\r': 
                case '\t': 
                      break;
                case '\n': 
                      line++;
                      break;
                default: 
                      if (isDigit(c)) {
                          numberToken();
                      } else {
                          Lox.error(line, format("Unexpected character: %c", c));
                      }
                      break;
            }
        }
    }

    private char peekNext() {
        if (current + 1 >= source.length) return '\0';
        return source[current + 1];
    } 

    private void numberToken() {
        while (isDigit(peek())) advance();

        // Look for a fractional part.
        if (peek() == '.' && isDigit(peekNext())) {
            // Consume the "."
            advance();

            while (isDigit(peek())) advance();
        }

        addToken(TokenType.NUMBER,
                to!double(source[start..current]));
    }

    private bool isDigit(char c) {
        return c >= '0' && c <= '9';
    }

    private void stringToken() {
        while (peek() != '"' && !isAtEnd()) {
            if (peek() == '\n') line++;
            advance();
        }

        if (isAtEnd()) {
            Lox.error(line, "Unterminated string.");
            return;
        }

        // The closing ".
        advance();

        // Trim the surrounding quotes.
        string value = source[start + 1..current - 1];
        addToken(TokenType.STRING, value);
    }

    private char peek() {
        if (isAtEnd()) return '\0';
        return source[current];
    }

    private bool match(char expected) {
        if (isAtEnd()) return false;
        if (source[current] != expected) return false;

        current++;
        return true;
    }

    private char advance() {
        return source[current++];
    }

    private void addToken(TokenType type) {
        addToken(type, null);
    }

    private void addToken(T)(TokenType type, T literal) {
        string text = source[start..current];
        tokens.insert(new Token(type, text, literal, line));
    }
    private bool isAtEnd() {
        return current >= source.length;
    }
}
