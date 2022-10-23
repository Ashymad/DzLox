import callable;
import std.variant;
import interpreter;
import instance;
import ast;
import fun;
import std.array;
import std.range;

class Cls : Instance, Callable {
    private Var[] props;
    private ulong _arity;
    private Cls metaclass;
    private Cls superclass;

    this(Var[] props, Var[] classprops = null, Interpreter interpreter = null, Cls superclass = null) {
        this.props = props;
        this.superclass = superclass;
        _arity = 0;
        foreach(prop; props) {
            if (prop.name.lexeme == "init") {
                if (auto fun = cast(Function) prop.initializer) {
                    _arity = fun.params.length;
                }
            }
        }
        if (classprops !is null) {
            metaclass = new Cls(classprops);
            super(metaclass.evalProps(interpreter));
            super.bindMethods("this");
            super.construct([], interpreter);
        } else {
            metaclass = null;
            super();
        }
    }

    Instance instatiate(Interpreter interpreter) {
        Instance[] instances = [new Instance(evalProps(interpreter))];
        for(Cls cls = this; cls.superclass; cls = cls.superclass) {
            instances ~= new Instance(cls.superclass.evalProps(interpreter));
        }
        instances[$-1].bindMethods("this", instances[0]);
        if (instances.length > 1) {
            foreach_reverse(ins; instances.slide(2)) {
                ins[0].bindMethods("super", ins[1]);
                ins[0].bindMethods("this", instances[0]);
                ins[0].addFields(ins[1].getFields());
            }
        }
        return instances[0];
    }

    Variant call(Interpreter interpreter, Variant[] arguments) {
        Instance instance = instatiate(interpreter);
        instance.addFields(super.getFields());
        instance.construct(arguments, interpreter);
        return Variant(instance);
    }

    private Variant[string] evalProps(Interpreter interpreter, Variant[string] fields = null) {
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
