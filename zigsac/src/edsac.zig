// EDSAC CPU core: shared by wasm.zig (browser simulator) and main.zig (CLI).
// TODO: main.zig duplicates the execute loop and tape/output helpers to support
// tracing
const std = @import("std");

pub const opcodes = "PQWERTYUIOJ#SZK*.F@D!HNM&LXGABCV";

// char to 5-bit code
pub const char_to_code = blk: {
    var table: [256]u5 = .{0} ** 256;
    const chars = opcodes;
    for (chars, 0..) |c, i| table[c] = @intCast(i);
    for (chars, 0..) |c, i| {
        if (c >= 'A' and c <= 'Z') table[c + 32] = @intCast(i);
    }
    for ('0'..'9' + 1, 0..) |c, i| table[c] = @intCast(i);
    // Perforator figure-mode characters
    table['+'] = 21; // H
    table['-'] = 22; // N
    break :blk table;
};

// 5-bit code to letter/figure char
pub const code_to_letter = blk: {
    var t = opcodes.*;
    t[18] = '\r'; // @ -> CR
    t[20] = ' ';  // ! -> space
    t[24] = '\n'; // & -> LF
    break :blk t;
};
pub const code_to_figure = "0123456789 #\"+( .$\r;  ,.\n)/#-?:=";

pub const initial_orders_1 = [_]u18{
    0x05000, 0x15004, 0x05000, 0x0300c, 0x00002, 0x0000a, 0x05000, 0x08000,
    0x1c000, 0x04020, 0x05001, 0x08004, 0x1c004, 0x0c00a, 0x0302a, 0x05006,
    0x1f002, 0x19010, 0x1c004, 0x05002, 0x03016, 0x04008, 0x1c002, 0x19001,
    0x1c000, 0x0503e, 0x1c032, 0x1c008, 0x07032, 0x0c03e, 0x1b00c,
};

pub const initial_orders_2 = [_]u18{
    0x05000, 0x03028, 0x00002, 0x07004, 0x1c04e, 0x04008, 0x1f000, 0x19010,
    0x05000, 0x08002, 0x1c002, 0x0c04e, 0x1b008, 0x19001, 0x0c04e, 0x03022,
    0x0c00e, 0x1c046, 0x05028, 0x1c000, 0x15010, 0x1c050, 0x05056, 0x1c02c,
    0x1c004, 0x0502c, 0x03044, 0x1c056, 0x03010, 0x1c054, 0x1c050, 0x03032,
    0x1c02c, 0x05054, 0x08051, 0x1c051, 0x04020, 0x05051, 0x03010, 0x0000b,
    0x00001,
};

pub const Cpu = struct {
    acc: i72 = 0,
    mult: i64 = 0,
    pc: u10 = 0,
    memory: [1024]u18 = .{0} ** 1024,

    pub fn norm(self: *Cpu) void {
        const bits: u71 = @truncate(@as(u72, @bitCast(self.acc)));
        self.acc = @as(i71, @bitCast(bits));
    }

    pub fn signExt(val: u36, long: bool) i72 {
        if (long) {
            return @as(i72, @intCast(val)) << 36;
        } else {
            const v17: u17 = @truncate(val);
            return @as(i72, @intCast(v17)) << 54;
        }
    }

    pub fn load(self: *const Cpu, addr: u10, long: bool) u36 {
        if (long) {
            const even = addr & 0x3FE;
            const lo: u36 = self.memory[even] & 0x1FFFF;
            const sandwich: u36 = (self.memory[even] >> 17) & 1;
            const hi: u36 = self.memory[even | 1] & 0x1FFFF;
            return (hi << 18) | (sandwich << 17) | lo;
        }
        return self.memory[addr] & 0x1FFFF;
    }

    pub fn store(self: *Cpu, addr: u10, long: bool) void {
        if (long) {
            const val: u36 = @truncate(@as(u72, @bitCast(self.acc)) >> 36);
            const even = addr & 0x3FE;
            self.memory[even] = @truncate((val & 0x1FFFF) | (((val >> 17) & 1) << 17));
            self.memory[even | 1] = @truncate((val >> 18) & 0x1FFFF);
        } else {
            const val: u17 = @truncate(@as(u72, @bitCast(self.acc)) >> 54);
            self.memory[addr] = val;
        }
    }

    pub fn multiply(self: *const Cpu, val: u36, long: bool) i72 {
        if (long) {
            const a: i128 = @as(i35, @bitCast(@as(u35, @truncate(val))));
            const b: i128 = @as(i35, @bitCast(@as(u35, @truncate(@as(u64, @bitCast(self.mult))))));
            const product = a * b;
            return @as(i72, @truncate(product)) << 2;
        } else {
            const a: i128 = @as(i17, @bitCast(@as(u17, @truncate(val))));
            const b: i128 = @as(i35, @bitCast(@as(u35, @truncate(@as(u64, @bitCast(self.mult))))));
            const product = a * b;
            return @as(i72, @truncate(product)) << 20;
        }
    }

    pub fn shift(val: i72, field: u12, left: bool) i72 {
        const amount: u7 = if (field == 0) (if (left) 13 else 15) else @as(u7, @ctz(field)) + 1;
        if (left) return val << amount else return val >> amount;
    }
};

pub const TapeReader = struct {
    tape: []const u8,
    pos: usize = 0,
    in_comment: bool = false,
    exhausted: bool = false,

    pub fn read(self: *TapeReader) u5 {
        while (self.pos < self.tape.len) {
            const c = self.tape[self.pos];
            self.pos += 1;

            if (c == '[') { self.in_comment = true; continue; }
            if (c == ']') { self.in_comment = false; continue; }
            if (self.in_comment) continue;
            if (c == ' ' or c == '\n' or c == '\r' or c == '\t') continue;

            return if (c < 32) @truncate(c ^ 0x10) else char_to_code[c];
        }
        self.exhausted = true;
        return 31;
    }
};

pub const OutputState = struct {
    last_output: u5 = 0,
    figure_shift: bool = false,
    output_to_tape: bool = false,
    input_from_tape: bool = false,
};

/// circular secondary tape. positions grow without bound; array access
/// wraps via modulo. safe as long as write_pos - read_pos < max_len
pub fn SecTape(comptime max_len: usize) type {
    return struct {
        data: [max_len]u8 = .{0} ** max_len,
        write_pos: usize = 0,
        read_pos: usize = 0,

        const Self = @This();

        pub fn write(self: *Self, code: u5) void {
            self.data[self.write_pos % max_len] = code;
            self.write_pos += 1;
        }

        pub fn read(self: *Self) u5 {
            if (self.read_pos < self.write_pos) {
                const val = self.data[self.read_pos % max_len];
                self.read_pos += 1;
                return @truncate(val ^ 0x10);
            }
            return 31;
        }

        pub fn rewind(self: *Self) void {
            self.read_pos = 0;
        }
    };
}

pub const RunResult = struct {
    steps: u32,
    halted: bool,
    tape_exhausted: bool = false,
};

/// execute up to max_steps instructions. pass 0 for unlimited.
/// returns the number of steps executed and whether the CPU halted
pub fn run(cpu: *Cpu, reader: *TapeReader, out: *OutputState, outputFn: *const fn (u8) void, sec_tape: anytype, max_steps: u32) RunResult {
    const c = char_to_code;
    var steps: u32 = 0;
    while (max_steps == 0 or steps < max_steps) {
        const inst = cpu.memory[cpu.pc];
        const opcode: u5 = @truncate(inst >> 12);
        const addr: u10 = @truncate(inst >> 1);
        const long = (inst & 1) == 1;
        const shift_field: u12 = @truncate(inst);

        cpu.pc +%= 1;
        steps += 1;

        switch (opcode) {
            c['E'] => if (cpu.acc >= 0) { cpu.pc = addr; },
            c['R'] => cpu.acc = Cpu.shift(cpu.acc, shift_field, false),
            c['T'] => { cpu.store(addr, long); cpu.acc = 0; },
            c['Y'] => cpu.acc +%= @as(i72, 1) << 35,
            c['U'] => cpu.store(addr, long),
            c['I'] => {
                const ch = if (out.input_from_tape) sec_tape.read() else reader.read();
                if (!out.input_from_tape and reader.exhausted)
                    return .{ .steps = steps, .halted = true, .tape_exhausted = true };
                if (long) {
                    cpu.memory[addr & 0x3FE] = 0;
                    cpu.memory[addr | 1] = ch;
                } else {
                    cpu.memory[addr] = ch;
                }
            },
            c['O'] => {
                const code: u5 = @truncate(cpu.memory[addr] >> 12);
                out.last_output = code;
                if (out.output_to_tape) sec_tape.write(code) else outputChar(code, out, outputFn);
            },
            c['S'] => { const m = cpu.load(addr, long); cpu.acc -%= Cpu.signExt(m, long); },
            c['Z'] => {
                const z_param: u11 = @truncate(inst >> 1);
                switch (z_param) {
                    1 => out.output_to_tape = false,
                    512 => { out.input_from_tape = true; sec_tape.rewind(); },
                    1024 => out.output_to_tape = true,
                    else => return .{ .steps = steps, .halted = true },
                }
            },
            c['F'] => {
                const val: u18 = @as(u18, out.last_output) << 12;
                if (long) {
                    cpu.memory[addr & 0x3FE] = 0;
                    cpu.memory[addr | 1] = val;
                } else {
                    cpu.memory[addr] = val;
                }
            },
            c['H'] => {
                const m = cpu.load(addr, long);
                if (long) {
                    cpu.mult = @bitCast(@as(u64, m));
                } else {
                    cpu.mult = @as(i64, @intCast(m)) << 18;
                }
            },
            c['N'] => { const m = cpu.load(addr, long); cpu.acc -%= cpu.multiply(m, long); },
            c['L'] => cpu.acc = Cpu.shift(cpu.acc, shift_field, true),
            c['X'] => {},
            c['G'] => if (cpu.acc < 0) { cpu.pc = addr; },
            c['A'] => { const m = cpu.load(addr, long); cpu.acc +%= Cpu.signExt(m, long); },
            c['C'] => {
                const m = cpu.load(addr, long);
                const um: u64 = @bitCast(cpu.mult);
                const r: u36 = if (long) @truncate(um) else @truncate(um >> 18);
                cpu.acc +%= Cpu.signExt(m & r, long);
            },
            c['V'] => { const m = cpu.load(addr, long); cpu.acc +%= cpu.multiply(m, long); },
            else => return .{ .steps = steps, .halted = true },
        }
        cpu.norm();
    }
    return .{ .steps = steps, .halted = false };
}

fn outputChar(code: u5, out: *OutputState, outputFn: *const fn (u8) void) void {
    if (code == 11) { out.figure_shift = true; return; } // #
    if (code == 15) { out.figure_shift = false; return; } // *
    if (code == 16) return; // blank tape

    const ch = if (out.figure_shift) code_to_figure[code] else code_to_letter[code];
    if (ch != ' ' or out.figure_shift or code == 20) {
        outputFn(ch);
    }
}
