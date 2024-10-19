const std = @import("std");
const safety = std.debug.runtime_safety;

const Position = struct {
    line: usize,
    byte: usize,
};

const ValidationResult = union(enum) {
    unmatched_opening: Position,
    unmatched_closing: Position,
    ok,

    pub fn format(
        res: ValidationResult,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (res) {
            .ok => {},
            inline .unmatched_opening, .unmatched_closing => |pos, tag| {
                const type_str = switch (tag) {
                    .unmatched_opening => "opening",
                    .unmatched_closing => "closing",
                    else => unreachable,
                };

                try writer.print("{d}:{d}: error: Unmatched {s} bracket\n", .{
                    pos.line, pos.byte, type_str,
                });
            },
        }
    }
};

fn validateSource(source: []const u8) ValidationResult {
    var bracket_depth: usize = 0;
    var pos: Position = .{ .line = 1, .byte = 0 };
    var last_pos = pos;

    for (source) |c| switch (c) {
        '[' => {
            bracket_depth += 1;
            last_pos = pos;
        },
        ']' => {
            bracket_depth, const overflow = @subWithOverflow(bracket_depth, 1);
            if (overflow == 1) return .{ .unmatched_closing = pos };
        },
        '\n' => {
            pos.line += 1;
            pos.byte = 0;
        },
        else => pos.byte += 1,
    };

    if (bracket_depth != 0)
        return .{ .unmatched_opening = last_pos };

    return .ok;
}

fn interpret(source: [:0]const u8) !u8 {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    errdefer |err| {
        var bw = std.io.bufferedWriter(std.io.getStdErr().writer());
        bw.writer().print("error: {s}\n", .{@errorName(err)}) catch {};
        bw.flush() catch {};
    }

    {
        const result = validateSource(source);
        if (result != .ok) {
            var bw = std.io.bufferedWriter(std.io.getStdErr().writer());
            try bw.writer().print("{}\n", .{result});
            try bw.flush();
            return 1;
        }
    }

    var data = [_]u8{0} ** 65536;
    var d: usize = 0;
    var i: usize = 0;
    while (true) : (i += 1) switch (source[i]) {
        '>' => d += 1,
        '<' => d -= 1,
        '+' => data[d] +%= 1,
        '-' => data[d] -%= 1,
        '.' => _ = try stdout.writeAll(data[d..][0..1]),
        ',' => {
            var in: [1]u8 = undefined;

            // Read until we have a byte
            while (try stdin.readAll(&in) == 0) {}

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
        0 => break,
        else => {},
    };

    return 0;
}

pub fn main() u8 {
    const usage =
        \\usage: bf [file]
        \\
    ;
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = if (safety) gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(gpa.allocator());
    defer if (safety) args.deinit();

    _ = args.next() orelse return 1;
    const filepath = args.next() orelse {
        std.io.getStdErr().writeAll(usage) catch {};
        return 1;
    };

    const source = std.fs.cwd().readFileAllocOptions(
        gpa.allocator(),
        filepath,
        std.math.pow(u64, 2, 32),
        null,
        1,
        0,
    ) catch {
        std.io.getStdErr().writeAll("error: could not read file\n") catch {};
        return 1;
    };
    defer if (safety) allocator.free(source);

    return interpret(source) catch 1;
}
