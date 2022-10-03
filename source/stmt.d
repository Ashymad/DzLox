import astgen;
import token;
import std.variant;
import expr;

static immutable string[][] statements = [
        ["Print", "Expr expression"],
        ["Expression", "Expr expression"],
        ["Var", "TokenI name", "Expr initializer"],
        ["Block", "Stmt[] statements"],
        ["If", "Expr condition", "Stmt thenBranch", "Stmt elseBranch"],
        ["While", "Expr condition", "Stmt bod"],
        ["Break"]
];

mixin(GenVisitor!(statements) ~ GenVisitee!("Stmt", statements));
