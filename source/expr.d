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
];

mixin(GenVisitor!(expressions) ~ GenVisitee!("Expr", expressions));
