const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigsac",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the EDSAC simulator");
    run_step.dependOn(&run_cmd.step);

    // WASM build
    const wasm = b.addExecutable(.{
        .name = "zigsac",
        .root_source_file = b.path("src/wasm.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });
    wasm.rdynamic = true;
    wasm.entry = .disabled;

    const wasm_step = b.step("wasm", "Build WASM module");
    const wasm_install = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "../web" } },
    });
    wasm_step.dependOn(&wasm_install.step);

    const test_step = b.step("test", "Run integration tests");

    const test_dir = b.path("test").getPath(b);
    var dir = std.fs.openDirAbsolute(test_dir, .{ .iterate = true }) catch return;
    defer dir.close();

    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        const name = entry.name;

        // Only process .expected files
        const stem = std.mem.trimRight(u8, name, " ");
        if (!std.mem.endsWith(u8, stem, ".expected")) continue;
        const base = stem[0 .. stem.len - ".expected".len];

        // Find matching input file and determine flags
        const inp = findInput(b.allocator, base, dir) catch null orelse continue;

        const expected_path = b.fmt("test/{s}.expected", .{base});
        const expected = std.fs.cwd().readFileAlloc(b.allocator, expected_path, 1024 * 1024) catch continue;

        const run = b.addRunArtifact(exe);
        run.addArg("-s");
        if (inp.flag) |f| run.addArg(f);
        run.setStdIn(.{ .lazy_path = b.path(b.fmt("test/{s}", .{inp.file})) });
        run.expectStdOutEqual(expected);

        test_step.dependOn(&run.step);
    }
}

fn findInput(alloc: std.mem.Allocator, base: []const u8, dir: std.fs.Dir) !?struct { file: []const u8, flag: ?[]const u8 } {
    const cases = [_]struct { ext: []const u8, flag: ?[]const u8 }{
        .{ .ext = ".ssi", .flag = "-b" },
        .{ .ext = ".e0", .flag = "-0" },
        .{ .ext = ".e1", .flag = null },
    };
    for (cases) |case| {
        const filename = try std.fmt.allocPrint(alloc, "{s}{s}", .{ base, case.ext });
        if (dir.statFile(filename)) |_| {
            return .{ .file = filename, .flag = case.flag };
        } else |_| {}
    }
    return null;
}
