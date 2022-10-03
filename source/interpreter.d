import expr;
import stmt;
import std.variant;
import tokentype;
import token;
import std.format;
import error;
import app;
import std.algorithm;
import astprinter;
import std.stdio;
import std.container;
import environment;

class Interpreter : stmt.Visitor, expr.Visitor {
    Variant value;
    Environment environment;

    private class BreakCalled : Exception {
        this() {
            super("", "", 0);
        }
    }

    this() {
        environment = new Environment();
    }

    string interpret(Array!Stmt statements) {
        try {
            foreach(statement; statements) {
                execute(statement);
            }
        } catch (RuntimeError error) {
            Lox.error(error);
        }
        return value == null ? "" : stringify(value);
    }

    private string stringify(Variant var) {
        if (var == null) return "nil";

        string str = var.toString();

        return str;
    }

    private void execute(Stmt stmt) {
        stmt.accept(this);
    }

    void visit(Expression stmt) {
        evaluate(stmt.expression);
    }

    void visit(Print stmt) {
        writeln(stringify(evaluate(stmt.expression)));
        value = null;
    }

    void visit(Var stmt) {
        Variant variant;
        if (stmt.initializer !is null) {
            variant = evaluate(stmt.initializer);
        }

        environment.define(stmt.name.lexeme, variant);
        value = null;
    }

    void visit(Block stmt) {
        executeBlock(stmt.statements, new Environment(environment));
    }

    void visit(If stmt) {
        if (isTruthy(evaluate(stmt.condition))) {
            execute(stmt.thenBranch);
        } else if (stmt.elseBranch !is null) {
            execute(stmt.elseBranch);
        }
    }

    void visit(Break _) {
        throw new BreakCalled();
    }

    void visit(While stmt) {
        while (isTruthy(evaluate(stmt.condition))) {
            try {
                execute(stmt.bod);
            } catch (BreakCalled _) break;
        }
        value = null;
    }

    void executeBlock(Stmt[] statements, Environment environment) {
        Environment previous = this.environment;
        try {
            this.environment = environment;

            foreach(statement; statements) {
                execute(statement);
            }
        } finally {
            this.environment = previous;
        }
    }

    void visit(Assign expr) {
        Variant variant = evaluate(expr.value);
        environment.assign(expr.name, variant);
        value = variant;
    }

    void visit(Variable expr) {
        Variant var = environment.get(expr.name);
        if (!var.hasValue())
            throw new RuntimeError(expr.name, "Variable is not initialized.");
        value = var;
    }

    void visit(Logical expr) {
        Variant left = evaluate(expr.left);

        if (expr.operator.type == TokenType.OR && isTruthy(left)) {
            value = left;
        } else if (expr.operator.type == TokenType.AND && !isTruthy(left)) {
            value = left;
        } else {
            value = evaluate(expr.right);
        }
    }

    void visit(Binary binary) {
        Variant left = evaluate(binary.left);
        Variant right = evaluate(binary.right); 

        with (TokenType) switch (binary.operator.type) {
            case MINUS:
                checkNumberOperands(binary.operator, left, right);
                value = left.get!(double) - right.get!(double);
                break;
            case SLASH:
                checkNumberOperands(binary.operator, left, right);
                if (right.get!(double) == 0)
                    throw new RuntimeError(binary.operator, "Division by zero");
                value = left.get!(double) / right.get!(double);
                break;
            case STAR:
                checkNumberOperands(binary.operator, left, right);
                value = left.get!(double) * right.get!(double);
                break;
            case PLUS:
                if (left.convertsTo!(double) && right.convertsTo!(double)) {
                    value = left.get!(double) + right.get!(double);
                } else if (left.convertsTo!(string) && right.convertsTo!(string)) {
                    value = left.get!(string) ~ right.get!(string);
                } else throw new RuntimeError(binary.operator, "Operants can be doubles or strings");
                break;
            case GREATER:
                checkNumberOperands(binary.operator, left, right);
                value = left.get!(double) > right.get!(double);
                break;
            case GREATER_EQUAL:
                checkNumberOperands(binary.operator, left, right);
                value = left.get!(double) >= right.get!(double);
                break;
            case LESS:
                checkNumberOperands(binary.operator, left, right);
                value = left.get!(double) < right.get!(double);
                break;
            case LESS_EQUAL:
                checkNumberOperands(binary.operator, left, right);
                value = left.get!(double) <= right.get!(double);
                break;
            case EQUAL_EQUAL:
                value = left == right;
                break;
            case BANG_EQUAL:
                value = left != right;
                break;
            case COMMA:
                value = right;
                break;
            default:
                assert(0);
        }
    }

    void visit(Ternary ternary) {
        assert(ternary.operator.type == TokenType.QUERY);
        if(isTruthy(evaluate(ternary.left))) {
            value = evaluate(ternary.middle);
        } else {
            value = evaluate(ternary.right);
        }
    }

    void visit(Grouping grouping) {
        value = evaluate(grouping.expression);
    }

    void visit(Literal literal) {
        value = literal.value;
    }

    void visit(Unary unary) {
        Variant right;
        if (unary.operator.type != TokenType.AST)
            right = evaluate(unary.right);

        with (TokenType) switch (unary.operator.type) {
            case MINUS:
                checkNumberOperands(unary.operator, right);
                value = -right.get!(double);
                break;
            case BANG:
                value = !isTruthy(right);
                break;
            case AST:
                value = new AstPrinter().print(unary.right);
                break;
            default: assert(0);
        }
    }

    private bool isTruthy(Variant var) {
        if (var == null) return false;
        if (var.type() == typeid(bool)) return var.get!(bool);
        return true;
    }

    private void checkNumberOperands(TokenI operator, Variant[] vars...) {
        foreach(var; vars) {
            if (!var.convertsTo!(double)) 
                throw new RuntimeError(operator,
                        format("Operand %s has wrong type: %s, double expected", stringify(var), var.type()));
        }
    }

    private Variant evaluate(Expr expr) {
        expr.accept(this);
        return value;
    }
}
