const std = @import("std");

pub fn validateSource(source: []const u8) !void {
    var bracket_depth: usize = 0;
    for (source) |c| switch (c) {
        '[' => bracket_depth = std.math.add(usize, bracket_depth, 1) catch return error.UnmatchedBrackets,
        ']' => bracket_depth = std.math.sub(usize, bracket_depth, 1) catch return error.UnmatchedBrackets,
        else => {},
    };

    if (bracket_depth != 0)
        return error.UnmatchedBrackets;
}

pub fn interpretSlow(source: [:0]const u8) !void {
    if (std.debug.runtime_safety) {
        validateSource(source) catch unreachable;
    }

    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    var data = [_]u8{0} ** 65536;
    var d: usize = 0;
    var i: usize = 0;
    while (i < source.len) : (i += 1) switch (source[i]) {
        '>' => d += 1,
        '<' => d -= 1,
        '+' => data[d] +%= 1,
        '-' => data[d] -%= 1,
        '.' => _ = try stdout.writeAll(data[d..][0..1]),
        ',' => {
            var in: [1]u8 = undefined;
            const bytes_read = try stdin.readAll(&in);
            if (bytes_read == 0) return error.Fug;

            data[d] = in[0];
        },
        '[' => {
            if (data[d] != 0) continue;

            i += 1;
            var depth: usize = 0;
            while (i < source.len) : (i += 1) {
                if (source[i] == '[') {
                    depth += 1;
                } else if (source[i] == ']') {
                    if (depth == 0) break;

                    depth -= 1;
                }
            }
        },
        ']' => {
            if (data[d] == 0) continue;

            var depth: usize = 0;
            while (i > 0) {
                i -= 1;

                if (source[i] == ']') {
                    depth += 1;
                } else if (source[i] == '[') {
                    if (depth == 0) break;

                    depth -= 1;
                }
            }
        },
        else => {},
    };
}

pub fn main() !void {
    const source = @embedFile("test.bf");
    try interpretSlow(source);
}
