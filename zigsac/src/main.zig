// CLI entry point for local development and testing (make run_zigsac, make format_zigsac).
// TODO: this duplicates the execute loop and tape/output helpers from edsac.zig to support
// tracing (-t flag)
const std = @import("std");
const edsac = @import("edsac.zig");

const Cpu = edsac.Cpu;
const opcodes = edsac.opcodes;
const char_to_code = edsac.char_to_code;
const code_to_letter = edsac.code_to_letter;
const code_to_figure = edsac.code_to_figure;

// i/o state
var last_output: u5 = 0;
var figure_shift: bool = false;
var tape: []const u8 = undefined;
var tape_pos: usize = 0;
var in_comment: bool = false;
var tape_exhausted: bool = false;
var out_count: u13 = 0;
var out_flush: u13 = 8;
var out_buf: std.io.BufferedWriter(4096, std.fs.File.Writer) = undefined;

// secondary storage tape
var output_to_tape: bool = false;
var input_from_tape: bool = false;
var sec_tape: std.ArrayList(u8) = undefined;
var sec_tape_read_pos: usize = 0;
var sec_tape_path: ?[]const u8 = null;

pub fn main() !void {
    out_buf = std.io.bufferedWriter(std.io.getStdOut().writer());
    defer out_buf.flush() catch {};
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    defer flushSecTape();

    var ssi_mode = false;
    var use_io1 = false;
    var trace_limit: usize = 0;
    var flush_interval: u13 = 8;
    var halt_skip: usize = 0;
    var argi: usize = 1;
    while (argi < args.len) : (argi += 1) {
        const arg = args[argi];
        if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--ssi")) ssi_mode = true;
        if (std.mem.eql(u8, arg, "-0")) use_io1 = true;
        if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--trace")) {
            trace_limit = std.math.maxInt(usize);
        } else if (std.mem.startsWith(u8, arg, "-t")) {
            trace_limit = std.fmt.parseInt(usize, arg[2..], 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "-f")) {
            const n = std.fmt.parseInt(u13, arg[2..], 10) catch 8;
            flush_interval = if (n == 0 or n > 4096) 8 else n;
        } else if (std.mem.startsWith(u8, arg, "-c")) {
            halt_skip = std.fmt.parseInt(usize, arg[2..], 10) catch 0;
        } else if (std.mem.eql(u8, arg, "-T") or std.mem.eql(u8, arg, "--tape")) {
            if (argi + 1 < args.len) { argi += 1; sec_tape_path = args[argi]; }
        }
    }
    out_flush = flush_interval;
    sec_tape = std.ArrayList(u8).init(allocator);

    const stdin = std.io.getStdIn();
    const input = try stdin.readToEndAlloc(allocator, 1024 * 1024);

    var cpu = Cpu{};

    if (ssi_mode) {
        var addr: usize = 0;
        var lines = std.mem.splitScalar(u8, input, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &[_]u8{ '\r', ' ', '\t' });
            if (trimmed.len == 0) continue;
            if (trimmed.len != 18) continue;
            var word: u18 = 0;
            for (trimmed) |c| {
                word = (word << 1) | @as(u18, if (c == '1') 1 else 0);
            }
            cpu.memory[addr] = word >> 1;
            addr += 1;
        }
    } else {
        tape = input;
        const orders = if (use_io1) &edsac.initial_orders_1 else &edsac.initial_orders_2;
        for (orders, 0..) |word, i| cpu.memory[i] = word;
    }

    var steps: usize = 0;
    while (true) {
        const inst = cpu.memory[cpu.pc];
        const opcode: u5 = @truncate(inst >> 12);
        const addr: u10 = @truncate(inst >> 1);
        const long = (inst & 1) == 1;
        const shift_field: u12 = @truncate(inst);

        var tape_char: ?u5 = null;
        var out_char: ?u5 = null;
        var mem_val: ?u36 = null;
        const pc = cpu.pc;
        steps += 1;

        cpu.pc +%= 1;

        const c = char_to_code;
        switch (opcode) {
            c['E'] => if (cpu.acc >= 0) { cpu.pc = addr; },
            c['R'] => cpu.acc = Cpu.shift(cpu.acc, shift_field, false),
            c['T'] => { cpu.store(addr, long); cpu.acc = 0; },
            c['Y'] => cpu.acc +%= @as(i72, 1) << 35,
            c['U'] => cpu.store(addr, long),
            c['I'] => {
                const ch = if (input_from_tape) readSecTape() else readTape();
                if (!input_from_tape and tape_exhausted) {
                    std.debug.print("Error: tape exhausted at location {d}\n", .{cpu.pc -% 1});
                    return;
                }
                if (long) {
                    cpu.memory[addr & 0x3FE] = 0;
                    cpu.memory[addr | 1] = ch;
                } else {
                    cpu.memory[addr] = ch;
                }
                tape_char = ch;
            },
            c['O'] => {
                const code: u5 = @truncate(cpu.memory[addr] >> 12);
                last_output = code;
                if (output_to_tape) tapeWrite(code) else output(code);
                out_char = code;
            },
            c['S'] => { const m = cpu.load(addr, long); mem_val = m; cpu.acc -%= Cpu.signExt(m, long); },
            c['Z'] => {
                const z_param: u11 = @truncate(inst >> 1);
                switch (z_param) {
                    1 => output_to_tape = false,
                    512 => { input_from_tape = true; sec_tape_read_pos = 0; },
                    1024 => output_to_tape = true,
                    else => if (halt_skip > 0) { halt_skip -= 1; } else return,
                }
            },
            c['F'] => {
                const val: u18 = @as(u18, last_output) << 12;
                if (long) {
                    cpu.memory[addr & 0x3FE] = 0;
                    cpu.memory[addr | 1] = val;
                } else {
                    cpu.memory[addr] = val;
                }
            },
            c['H'] => {
                const m = cpu.load(addr, long);
                mem_val = m;
                if (long) {
                    cpu.mult = @bitCast(@as(u64, m));
                } else {
                    cpu.mult = @as(i64, @intCast(m)) << 18;
                }
            },
            c['N'] => { const m = cpu.load(addr, long); mem_val = m; cpu.acc -%= cpu.multiply(m, long); },
            c['L'] => cpu.acc = Cpu.shift(cpu.acc, shift_field, true),
            c['X'] => {
                if (addr == 40) std.debug.print("ACC: {d} (0x{x})\n", .{ cpu.acc, cpu.acc });
                if (addr == 41) std.debug.print("MULT: {d} (0x{x})\n", .{ cpu.mult, cpu.mult });
            },
            c['G'] => if (cpu.acc < 0) { cpu.pc = addr; },
            c['A'] => { const m = cpu.load(addr, long); mem_val = m; cpu.acc +%= Cpu.signExt(m, long); },
            c['C'] => {
                const m = cpu.load(addr, long);
                mem_val = m;
                const um: u64 = @bitCast(cpu.mult);
                const r: u36 = if (long) @truncate(um) else @truncate(um >> 18);
                cpu.acc +%= Cpu.signExt(m & r, long);
            },
            c['V'] => { const m = cpu.load(addr, long); mem_val = m; cpu.acc +%= cpu.multiply(m, long); },
            else => {
                std.debug.print("Undefined order {c} at location {d}\n", .{ opcodes[opcode], cpu.pc -% 1 });
                return;
            },
        }
        cpu.norm();

        if (steps - 1 < trace_limit) {
            const fd: u8 = if (long) 'D' else 'F';
            const u: u72 = @bitCast(cpu.acc);
            const um: u64 = @bitCast(cpu.mult);
            std.debug.print("{d:3} {d:4} {c}{d:4}{c} {X:0>5}|{d}|{X:0>5}|{d}|{X:0>5}|{d}|{X:0>5} {X:0>5}|{d}|{X:0>5}", .{
                steps - 1, pc, opcodes[opcode], @as(u11, @truncate(inst >> 1)), fd,
                @as(u17, @truncate(u >> 54)), @as(u1, @truncate(u >> 53)),
                @as(u17, @truncate(u >> 36)), @as(u1, @truncate(u >> 35)),
                @as(u17, @truncate(u >> 18)), @as(u1, @truncate(u >> 17)),
                @as(u17, @truncate(u)),
                @as(u17, @truncate(um >> 18)), @as(u1, @truncate(um >> 17)),
                @as(u17, @truncate(um)),
            });
            if (mem_val) |m| {
                if (long) {
                    std.debug.print(" {X:0>5}|{d}|{X:0>5}", .{
                        @as(u17, @truncate(m >> 18)), @as(u1, @truncate(m >> 17)), @as(u17, @truncate(m)),
                    });
                } else {
                    std.debug.print(" {X:0>5}", .{@as(u17, @truncate(m))});
                }
            }
            if (tape_char) |ch| std.debug.print(" I:{X:0>2}", .{ch});
            if (out_char) |ch| std.debug.print(" O:{X:0>2}", .{ch});
            std.debug.print("\n", .{});
        }
    }
}

fn readTape() u5 {
    while (tape_pos < tape.len) {
        const c = tape[tape_pos];
        tape_pos += 1;

        if (c == '[') { in_comment = true; continue; }
        if (c == ']') { in_comment = false; continue; }
        if (in_comment) continue;
        if (c == ' ' or c == '\n' or c == '\r' or c == '\t') continue;

        return if (c < 32) @truncate(c ^ 0x10) else char_to_code[c];
    }
    tape_exhausted = true;
    return 31;
}

fn output(code: u5) void {
    if (code == 11) { figure_shift = true; return; } // #
    if (code == 15) { figure_shift = false; return; } // *
    if (code == 16) return; // blank tape

    const ch = if (figure_shift) code_to_figure[code] else code_to_letter[code];
    if (ch != ' ' or figure_shift or code == 20) {
        out_buf.writer().writeByte(ch) catch {};
        out_count += 1;
        if (out_count >= out_flush) { out_buf.flush() catch {}; out_count = 0; }
    }
}

fn tapeWrite(code: u5) void {
    sec_tape.append(code) catch {};
}

fn readSecTape() u5 {
    if (sec_tape_read_pos < sec_tape.items.len) {
        const val = sec_tape.items[sec_tape_read_pos];
        sec_tape_read_pos += 1;
        return @truncate(val ^ 0x10);
    }
    return 31;
}

fn flushSecTape() void {
    if (sec_tape_path) |path| {
        const file = std.fs.cwd().createFile(path, .{}) catch return;
        defer file.close();
        file.writeAll(sec_tape.items) catch {};
    }
}
