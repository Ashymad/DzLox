import astgen;
import token;
import std.variant;

static immutable string[][] expressions = [
        ["Ternary", "Expr left", "TokenI operator", "Expr middle", "Expr right"],
        ["Binary", "Expr left", "TokenI operator", "Expr right"],
        ["Grouping", "Expr expression"],
        ["Literal", "Variant value"],
        ["Unary", "TokenI operator", "Expr right"],
        ["Variable", "TokenI name"],
        ["Assign", "TokenI name",  "Expr value"],
        ["Logical", "Expr left", "TokenI operator", "Expr right"],
        ["Call", "Expr callee", "TokenI paren", "Expr[] arguments"],
        ["Function", "TokenI[] params", "Stmt[] body"],
        ["Class", "Var[] methods", "Var[] classmethods", "Variable superclass"],
        ["Get", "Expr object", "TokenI name"],
        ["Set", "Expr object", "TokenI name", "Expr value"],
        ["This", "TokenI keyword"],
        ["Super", "TokenI keyword"],
];

static immutable string[][] statements = [
        ["Print", "Expr expression"],
        ["Expression", "Expr expression"],
        ["Var", "TokenI name", "Expr initializer"],
        ["Block", "Stmt[] statements"],
        ["If", "Expr condition", "Stmt thenBranch", "Stmt elseBranch"],
        ["While", "Expr condition", "Stmt bod"],
        ["Break", "TokenI keyword"],
        ["Return", "TokenI keyword", "Expr value"],
];

mixin(GenAst!("Stmt", statements) ~ GenAst!("Expr", expressions));
