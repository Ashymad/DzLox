import std.conv;
import std.algorithm.iteration;
import std.array;
import ast;

class AstPrinter : ExprVisitor {
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
    void visit(Function fun) {
        printed = "(fun (" ~ fun.params.map!(p => p.lexeme).join(" ") ~  ") {...})";
    }
    void visit(Class cls) {
        printed = "(class " ~ cls.methods.map!(p => p.name.lexeme ~ "()").join(" ") ~  ")";
    }
    void visit(Unary unary) {
        printed = parenthesize(unary.operator.lexeme, unary.right);
    }
    void visit(Call call) {
        printed = parenthesize("call", call.callee ~ call.arguments);
    }
    void visit(Get get) {
        printed = parenthesize("get", get.object, new Variable(get.name));
    }
    void visit(Set get) {
        printed = parenthesize("set", get.object, new Variable(get.name), get.value);
    }
    void visit(This th) {
        printed = th.keyword.lexeme;
    }
    private string parenthesize(string name, Expr[] exprs ...) {
        return "(" ~ name ~ " " ~ exprs.map!(e => print(e)).join(" ") ~  ")";
    }
}
