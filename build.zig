const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "bf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);

    if (b.args) |args| {
        run.addArgs(args);
    }

    b.step("run", "Run the program").dependOn(&run.step);
}
