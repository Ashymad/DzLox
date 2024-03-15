import interpreter;
import std.variant;

interface Callable {
    Variant call(Interpreter interpreter, Variant[] arguments);
    ulong arity();
}
