import std.array;
import std.format;
import std.algorithm.iteration;
import std.uni;
import std.algorithm.iteration;

template GenVisitee(immutable string basename, immutable string[][] names) {
    const char[] GenVisitee = format("interface %s { void accept(Visitor visitor); }", basename) ~
        names.map!(name => format(
            "class %s:%s{%s;this(%s){%s;}void accept(Visitor visitor){visitor.visit(this);}}",
            name[0], basename, name[1..$].join(";"), name[1..$].join(","),
            name[1..$].map!(s => "this." ~ [s.split(" ")[$-1]].replicate(2).join("=")).join(";"))).join();
}

template GenVisitor(immutable string[][] names) {
    const char[] GenVisitor = format("interface Visitor{%s;}",
            names.map!(s => format("void visit(%s %s)", s[0], "_" ~ toLower(s[0]))).join(";"));
}
