import cls;
import token;
import error;
import std.variant;
import fun;

class Instance {
    private Cls cls;
    private Variant[string] fields;

    this(Cls cls, Variant[string] fields) {
        this.cls = cls;
        this.fields = fields;
    }

    this(Instance inst) {
        this.cls = inst.cls;
        this.fields = inst.fields.dup;
    }

    Variant get(TokenI name) {
        if (auto field = name.lexeme in fields) {
            if (field.convertsTo!(Fun)) {
                return Variant(field.get!(Fun).bind(this));
            }
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
}
