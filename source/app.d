import std.stdio;
import std.file;
import std.container;
import token;
import scaner;
import deimos.linenoise;
import std.string;
import std.conv;
import keywords;

int main(string[] args) {
    Lox lox = new Lox;
    if (args.length > 2) {
        writeln("Usage: dlox [script]");
        return 64;
    } else if (args.length == 2) {
        lox.runFile(args[1]);
    } else {
        lox.runPrompt();
    }
    if (lox.hadError) return 65;
    return 0;
}

class Lox {
    static bool hadError = false;

    extern(C) static void completion(const char *buf, linenoiseCompletions *lc) {
        auto bufs = fromStringz(buf);
        auto lastsp = lastIndexOfAny(bufs, [' ', '\t']) + 1;
        auto klen = bufs.length - lastsp;
        if (bufs.length <= 0) return;

        foreach (key; keywords.keywords.keys) {
            if (klen <= key.length && bufs[lastsp..bufs.length] == key[0..klen]) {
                linenoiseAddCompletion(lc, toStringz(bufs[0..lastsp] ~ key));
            }
        }
    }

    void runFile(string file) {
        run(to!(char[])(readText(file)));
    }

    void runPrompt() {
        char* line;
        const char* history = ".dlox_history";

        linenoiseSetCompletionCallback(&completion);
        linenoiseHistoryLoad(history);

        while((line = linenoise("lox> ")) !is null) {
            if (line[0] != '\0' && line[0] != '/') {
                linenoiseHistoryAdd(line);
                linenoiseHistorySave(history);
            }
            run(fromStringz(line));
            hadError = false;
        }
    }

    void run(char[] source) {
        Scanner scanner = new Scanner(source);

        auto tokens = scanner.scanTokens();
        foreach (token; tokens) {
            writeln(token);
        }
    }

    static void error(int line, string msg) {
        report(line, "", msg);
    }

    static void report(int line, string where, string msg) {
        writefln("[line %s] Error%s: %s", line, where, msg);
        hadError = true;
    }
}

