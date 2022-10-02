import std.conv;
import std.algorithm.iteration;
import std.array;
import expr;

class AstPrinter : Visitor {
    string printed;

    string print(Expr expr) {
        expr.accept(this);
        return printed;
    }
    void visit(Binary binary) {
        printed = parenthesize(binary.operator.lexeme,
                binary.left, binary.right);
    }
    void visit(Logical binary) {
        printed = parenthesize(binary.operator.lexeme,
                binary.left, binary.right);
    }
    void visit(Ternary ternary) {
        printed = parenthesize(ternary.operator.lexeme,
                ternary.left, ternary.middle, ternary.right);
    }
    void visit(Grouping grouping) {
        printed = parenthesize("group", grouping.expression);
    }
    void visit(Assign assign) {
        printed = parenthesize("= " ~ assign.name.lexeme, assign.value);
    }
    void visit(Variable variable) {
        printed = variable.name.lexeme;
    }
    void visit(Literal literal) {
        if (literal.value == null) printed = "nil";
        printed = literal.value.toString();
    }
    void visit(Unary unary) {
        printed = parenthesize(unary.operator.lexeme, unary.right);
    }
    private string parenthesize(string name, Expr[] exprs ...) {
        return "(" ~ name ~ " " ~ exprs.map!(e => print(e)).join(" ") ~  ")";
    }
}
