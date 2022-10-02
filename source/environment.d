import std.variant;
import token;
import error;

class Environment {
    private Variant[string] values;

    Environment enclosing;

    this() {
        enclosing = null;
    }

    this(Environment env) {
        enclosing = env;
    }

    void define(string name, Variant value) {
        values[name] = value;
    }

    private Variant* find(TokenI name) {
        Variant* value = name.lexeme in values;
        if (value is null) {
            if (enclosing !is null) return enclosing.find(name);
            throw new RuntimeError(name, "Undefined variable '" ~ name.lexeme ~ "'.");
        }
        return value;
    }

    Variant get(TokenI name) {
        return *find(name);
    }

    void assign(TokenI name, Variant new_value) {
        *find(name) = new_value;
    }
}
