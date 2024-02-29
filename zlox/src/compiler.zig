const std = @import("std");
const scanner = @import("scanner.zig");

pub const CompilerError = scanner.ScannerError;

pub fn compile(source: []const u8) !void {
    var Scanner = try scanner.Scanner.init(source);

    var line: i32 = -1;

    while (true) {
        const token = try Scanner.scanToken();
        if (token.line != line) {
            std.debug.print("{d:4} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{s:15} '{s}'\n", .{ @tagName(token.type), token.lexeme });

        if (token.type == scanner.TokenType.EOF) break;
    }
}
