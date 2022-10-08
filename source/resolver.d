import interpreter;
import ast;
import std.container;
import std.range;
import token;
import app;

class Resolver : StmtVisitor, ExprVisitor {
    private Interpreter interpreter;
    private SList!(bool[string]) scopes;
    private FunctionType currentFunction = FunctionType.NONE;
    private LoopType currentLoop = LoopType.NONE;

    private enum FunctionType {
        NONE,
        FUN
    }

    private enum LoopType {
        NONE,
        WHILE
    }

    this(Interpreter interpreter) {
        this.interpreter = interpreter;
        this.scopes = SList!(bool[string])();
    }

    void resolve(T)(T[] statements...) {
        foreach(statement; statements) {
            statement.accept(this);
        }
    }

    void beginScope() {
        scopes.insertFront(null);
    }

    private void endScope() {
        scopes.removeFront();
    }

    private void declare(TokenI name) {
        if(scopes.empty()) return;

        auto sco = scopes.front();
        if(name.lexeme in sco) {
            Lox.error(name, "Already a variable with this name in this scope.");
        }
        sco[name.lexeme] = false;
    }

    private void define(TokenI name) {
        if(scopes.empty()) return;

        scopes.front()[name.lexeme] = true;
    }

    private void resolveLocal(Expr expr, TokenI name) {
        foreach(i, sco; scopes[].enumerate()) {
            if(name.lexeme in sco) {
                interpreter.resolve(expr, i);
            }
        }
    }

    void visit(Print _print) {
        resolve(_print.expression);
    }

    void visit(Expression _expression) {
        resolve(_expression.expression);
    }

    void visit(Var stmt) {
        declare(stmt.name);
        if (stmt.initializer !is null) {
            resolve(stmt.initializer);
        }
        define(stmt.name);
    }

    void visit(Block stmt) {
        beginScope();
        resolve(stmt.statements);
        endScope();
    }

    void visit(If _if) {
        resolve(_if.condition);
        resolve(_if.thenBranch);
        if (_if.elseBranch !is null) resolve(_if.elseBranch);
    }

    void visit(While _while) {
        resolve(_while.condition);
        LoopType enclosingLoop = currentLoop;
        currentLoop = LoopType.WHILE;
        resolve(_while.bod);
        currentLoop = enclosingLoop;
    }

    void visit(Break _break) {
        if (currentLoop == LoopType.NONE) {
            Lox.error(_break.keyword, "Can't break outside a loop.");
        }
    }

    void visit(Return _return) {
        if (currentFunction == FunctionType.NONE) {
            Lox.error(_return.keyword, "Can't return from top-level code.");
        }
        if (_return.value !is null) resolve(_return.value);
    }

    void visit(Ternary _ternary) {
        resolve(_ternary.left);
        resolve(_ternary.middle);
        resolve(_ternary.right);
    }

    void visit(Binary _binary) {
        resolve(_binary.left);
        resolve(_binary.right);
    }

    void visit(Grouping _grouping) {
        resolve(_grouping.expression);
    }

    void visit(Literal _) {}

    void visit(Unary _unary) {
        resolve(_unary.right);
    }

    void visit(Variable expr) {
        if (!scopes.empty() && !scopes.front().get(expr.name.lexeme, true)) {
            Lox.error(expr.name, "Can't read local variable in its own initializer.");
        }

        resolveLocal(expr, expr.name);
    }
    void visit(Assign expr) {
        resolve(expr.value);
        resolveLocal(expr, expr.name);
    }

    void visit(Logical _logical) {
        resolve(_logical.left);
        resolve(_logical.right);
    }

    void visit(Call _call) {
        resolve(_call.callee);

        foreach(arg; _call.arguments) {
            resolve(arg);
        }
    }

    void visit(Function expr) {
        FunctionType enclosingFunction = currentFunction;
        currentFunction = FunctionType.FUN;
        beginScope();
        foreach (param; expr.params) {
            declare(param);
            define(param);
        }
        resolve(expr.body);
        endScope();
        currentFunction = enclosingFunction;
    }
}
