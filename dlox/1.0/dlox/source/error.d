import std.exception;
import token;

class RuntimeError : Exception {
    const TokenI token;

    this(TokenI token, string msg, string file = __FILE__, size_t line = __LINE__) {
        this.token = token;
        super(msg, file, line);
    }
}
