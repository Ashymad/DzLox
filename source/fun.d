import callable;
import ast;
import interpreter;
import environment;
import std.variant;

class Fun : Callable {
    private Function fun;
    private Environment closure;

    this(Function fun, Environment closure) {
        this.closure = closure;
        this.fun = fun;
    }

    Variant call(Interpreter interpreter, Variant[] arguments) {
        Environment environment = new Environment(closure);
        for(int i = 0; i < fun.params.length; i++) {
            environment.define(fun.params[i].lexeme, arguments[i]);
        }

        try {
            interpreter.executeBlock(fun.body, environment);
        } catch (Interpreter.ReturnCalled ret) {
            return ret.value;
        }
        return Variant(null);
    }

    ulong arity() {
        return fun.params.length;
    }

    void toString(scope void delegate(const(char)[]) sink) const {
        sink("<fun>");
    }
}
