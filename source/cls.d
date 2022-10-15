import callable;
import std.variant;
import interpreter;
import instance;
import ast;
import fun;
import std.array;

class Cls : Instance, Callable {
    private Var[] props;
    private ulong _arity;
    private Cls meta;

    this(Var[] props, Var[] classprops = null, Interpreter interpreter = null) {
        this.props = props;
        _arity = 0;
        foreach(prop; props) {
            if (prop.name.lexeme == "init") {
                if (auto fun = cast(Function) prop.initializer) {
                    _arity = fun.params.length;
                }
            }
        }
        if (classprops !is null) {
            this.meta = new Cls(classprops);
            super(meta.evalProps(interpreter));
            super.construct([], interpreter);
        } else {
            this.meta = null;
            super();
        }
    }

    Variant call(Interpreter interpreter, Variant[] arguments) {
        Variant[string] fields = evalProps(interpreter);
        Instance instance = new Instance(fields);
        instance.addFields(super.getFields());
        instance.construct(arguments, interpreter);
        return Variant(instance);
    }

    private Variant[string] evalProps(Interpreter interpreter) {
        Variant[string] fields = null;
        foreach(prop; props) {
            fields[prop.name.lexeme] = interpreter.evaluate(prop.initializer);
        }
        return fields;
    }

    ulong arity() {
        return _arity;
    }

    override void toString(scope void delegate(const(char)[]) sink) const {
        sink("<class>");
    }
}
