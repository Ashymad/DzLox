import token;
import error;
import std.variant;
import fun;
import interpreter;
import std.range;
import std.algorithm;

class Instance {
    private Variant[string] fields;
    private Fun constructor;

    this(Variant[string] fields = null) {
        this.fields = fields;
        this.constructor = null;
        if (this.fields) bindMethods();
    }

    this(Instance inst) {
        this.fields = inst.fields.dup;
        this.constructor = null;
        if (this.fields) bindMethods();
    }

    Variant get(TokenI name) {
        if (auto field = name.lexeme in fields) {
            return *field;
        }
        throw new RuntimeError(name,
                "Undefined property '" ~ name.lexeme ~ "'.");
    }

    void set(TokenI name, Variant value) {
        fields[name.lexeme] = value;
    }

    void toString(scope void delegate(const(char)[]) sink) const {
        sink("<class instance>");
    }

    void addFields(Variant[string] newf) {
        foreach(name, value; newf.byPair) {
            fields.require(name, value);
        }
    }

    Variant[string] getFields() {
        return fields;
    }

    private void bindMethods() {
        foreach(name, field; fields.byPair) {
            if (field.convertsTo!(Fun)) {
                auto ifun = field.get!(Fun).bind(this);
                if (name == "init") {
                    ifun.setInitializer();
                    constructor = ifun;
                }
                fields[name] = Variant(ifun);
            }
        }
    }

    void construct(Variant[] arguments, Interpreter interpreter) {
        if(constructor) constructor.call(interpreter, arguments);
    }
}
