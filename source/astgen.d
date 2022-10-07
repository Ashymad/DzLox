import std.array;
import std.format;
import std.algorithm.iteration;
import std.uni;
import std.algorithm.iteration;

template GenAst(immutable string basename, immutable string[][] names) {
    const char[] GenAst = format("interface %sVisitor{%s;}", basename,
            names.map!(s => format("void visit(%s %s)", s[0], "_" ~ toLower(s[0]))).join(";")) 
            ~ format("interface %s { void accept(%sVisitor visitor); }", basename, basename) ~
        names.map!(name => format(
            "class %s:%s{%sthis(%s){%s}void accept(%sVisitor visitor){visitor.visit(this);}}",
            name[0],
            basename,
            name[1..$].join(";") ~ (name.length > 1 ? ";" : ""),
            name[1..$].join(","),
            name[1..$].map!(s =>
                "this." ~ [s.split(" ")[$-1]].replicate(2).join("=")
            ).join(";") ~ (name.length > 1 ? ";" : ""),
            basename
        )).join();
}
