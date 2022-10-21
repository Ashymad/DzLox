import callable;
import ast;
import interpreter;
import environment;
import std.variant;
import instance;
import tokentype;
import token;

class Fun : Callable {
    private Function fun;
    private Environment closure;
    private bool isInitializer;

    this(Function fun, Environment closure, bool isInitializer = false) {
        this.closure = closure;
        this.fun = fun;
        this.isInitializer = isInitializer;
    }

    void setInitializer() {
        isInitializer = true;
    }

    Variant call(Interpreter interpreter, Variant[] arguments) {
        Environment environment = new Environment(closure);
        for(int i = 0; i < fun.params.length; i++) {
            environment.define(fun.params[i].lexeme, arguments[i]);
        }

        try {
            interpreter.executeBlock(fun.body, environment);
        } catch (Interpreter.ReturnCalled ret) {
            return retv(ret.value);
        }

        return retv(Variant(null));
    }

    Variant retv(Variant value) {
        if (isInitializer) return Variant(new Instance(closure.get(
                TokenI(TokenType.THIS, "this", null, -1)).get!(Instance)));
        return value;
    }

    Fun bind(string name, Instance instance) {
        Environment environment = new Environment(closure);
        environment.define(name, Variant(instance));
        return new Fun(fun, environment, isInitializer);
    }

    ulong arity() {
        return fun.params.length;
    }

    void toString(scope void delegate(const(char)[]) sink) const {
        sink("<fun>");
    }
}
