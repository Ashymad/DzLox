import std.variant;
import core.exception;
import token;
import std.stdio;
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

    Environment ancestor(size_t distance) {
        Environment environment = this;
        foreach(_; 0..distance) {
            environment = environment.enclosing;
        }

        return environment;
    }

    Variant get(TokenI name) {
        return *find(name);
    }

    void assign(TokenI name, Variant new_value) {
        *find(name) = new_value;
    }
    
    Variant getAt(TokenI name, size_t distance) {
        try {
            return ancestor(distance).values[name.lexeme];
        } catch (RangeError err) {
            stderr.writefln("Resolved variable %s not at distance %s!", name.lexeme, distance);
            throw err;
        }
    }

    void assignAt(TokenI name, Variant value, size_t distance) {
        ancestor(distance).values[name.lexeme] = value;
    }

}
