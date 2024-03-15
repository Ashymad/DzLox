import std.variant : Variant;
import std.format;
import std.algorithm;
import std.stdio;
import std.container;
import std.datetime.systime;
import ast;
import tokentype;
import token;
import error;
import app;
import astprinter;
import environment;
import callable;
import fun;
import cls;
import instance;

class Interpreter : StmtVisitor, ExprVisitor {
    private Variant value;
    private Environment environment;
    private Environment globals;
    private size_t[Expr] locals;

    class BreakCalled : Exception {
        this() {
            super("", "", 0);
        }
    }

    class ReturnCalled : Exception {
        Variant value;
        this(Variant value) {
            this.value = value;
            super("", "", 0);
        }
    }

    this() {
        globals = new Environment();
        environment = globals;
        locals = null;
        value = Variant(null);
        
        globals.define("clock", Variant(new class Callable {
                    ulong arity() {
                        return 0;
                    }
                    Variant call(Interpreter _, Variant[] __) {
                        return Variant(stdTimeToUnixTime(Clock.currStdTime()));
                    }
        }));
    }

    string interpret(Stmt[] statements) {
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

    void resolve(Expr expr, size_t depth) {
        locals[expr] = depth;
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
        Variant variant = Variant(null);
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

    void visit(Return ret) {
        throw new ReturnCalled(ret.value is null ? Variant(null) : evaluate(ret.value));
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

    void visit(Function expr) {
        value = new Fun(expr, environment);
    }

    void visit(Class expr) {
        Cls superclass = null;
        if (expr.superclass) {
            auto var = evaluate(expr.superclass);
            if (var.convertsTo!(Cls))
                superclass = var.get!(Cls);
            else
                throw new RuntimeError(expr.superclass.name,
                        "Attempt to subclass non-class");
        }
        value = new Cls(expr.methods, expr.classmethods, this, superclass);
    }

    void visit(Get expr) {
        Variant object = evaluate(expr.object);
        if (!object.convertsTo!(Instance)) {
            throw new RuntimeError(expr.name,
                    "Attempt to acces property of non-instace object");
        }
        value = object.get!(Instance).get(expr.name);
    }

    void visit(Set expr) {
        Variant object = evaluate(expr.object);
        if (!object.convertsTo!(Instance)) {
            throw new RuntimeError(expr.name,
                    "Attempt to set property of non-instace object");
        }
        Variant val = evaluate(expr.value);
        object.get!(Instance).set(expr.name, val);
        value = val;
    }

    void visit(This expr) {
        value = lookUpVariable(expr.keyword, expr);
    }

    void visit(Super expr) {
        value = lookUpVariable(expr.keyword, expr);
    }

    void visit(Call expr) {
        Variant callee = evaluate(expr.callee);
        Variant[] arguments = [];

        foreach(arg; expr.arguments) {
            arguments ~= evaluate(arg);
        }

        if (!callee.convertsTo!(Callable)) {
            throw new RuntimeError(expr.paren, "Expression result is not callable");
        }
        Callable fun = callee.get!(Callable);
        if (arguments.length != fun.arity()) {
            throw new RuntimeError(expr.paren,
                    format("Expected %s arguments but got %s.", fun.arity(), arguments.length));
        }
        value = fun.call(this, arguments);
    }

    void visit(Assign expr) {
        Variant variant = evaluate(expr.value);
        if(size_t* distance = expr in locals) {
            environment.assignAt(expr.name, value, *distance);
        } else {
            globals.assign(expr.name, variant);
        }
        value = variant;
    }

    void visit(Variable expr) {
        value = lookUpVariable(expr.name, expr);
    }

    private Variant lookUpVariable(TokenI name, Expr expr) {
        if(size_t* distance = expr in locals) {
            return environment.getAt(name, *distance);
        } else {
            return globals.get(name);
        }
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
                value = left.type() == right.type() && left == right;
                break;
            case BANG_EQUAL:
                value = left.type() != right.type() || left != right;
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

    Variant evaluate(Expr expr) {
        expr.accept(this);
        return value;
    }
}
