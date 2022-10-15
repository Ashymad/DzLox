import callable;
import std.variant;
import interpreter;
import instance;
import ast;
import fun;
import std.array;

class Cls : Callable {
    private Var[] props;
    private ulong _arity;

    this(Var[] props) {
        this.props = props;
        _arity = 0;
        foreach(prop; props) {
            if (prop.name.lexeme == "init") {
                if (auto fun = cast(Function) prop.initializer) {
                    _arity = fun.params.length;
                }
            }
        }
    }

    Variant call(Interpreter interpreter, Variant[] arguments) {
        Variant[string] fields = null;
        foreach(prop; props) {
            fields[prop.name.lexeme] = interpreter.evaluate(prop.initializer);
        }
        Instance instance = new Instance(this, fields);
        if (auto fun = "init" in fields) {
            if (fun.convertsTo!(Fun)) {
                auto ifun = fun.get!(Fun);
                ifun.setInitializer();
                ifun.bind(instance).call(interpreter, arguments);
                *fun = Variant(ifun);
            }
        }
        return Variant(instance);
    }

    ulong arity() {
        return _arity;
    }

    void toString(scope void delegate(const(char)[]) sink) const {
        sink("<class>");
    }
}
