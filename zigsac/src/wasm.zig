// WASM build: browser-facing simulator, exported to JS via index.html.
// Uses edsac.run() for execution — this is the production path.
const edsac = @import("edsac.zig");

var tape_buf: [64 * 1024]u8 = undefined;
var cpu: edsac.Cpu = .{};
var reader: edsac.TapeReader = .{ .tape = &.{} };
var out: edsac.OutputState = .{};
var sec_tape: edsac.SecTape(256 * 1024) = .{};
var halted: bool = true;
var tape_exhausted: bool = false;
var total_steps: u32 = 0;

// Shared state buffer, readable from JS via getStatePtr().
// Layout (u32 slots):
//   [0..3]     acc (72 bits in 3 x u32, little-endian)
//   [3..5]     mult (64 bits in 2 x u32, little-endian)
//   [5]        pc
//   [6]        total_steps
//   [7]        halted (0 or 1)
//   [8..1032]  memory (1024 x u18, each in a u32)
var state: [8 + 1024]u32 = .{0} ** (8 + 1024);

extern "env" fn outputByte(byte: u8) void;

fn wasmOutput(byte: u8) void {
    outputByte(byte);
}

export fn getTapeBuffer() [*]u8 {
    return &tape_buf;
}

/// Returns byte offset of the state buffer within WASM linear memory.
export fn getStatePtr() [*]u32 {
    return &state;
}

/// Copy current CPU state into the shared buffer.
export fn syncState() void {
    const u: u72 = @bitCast(cpu.acc);
    state[0] = @truncate(u);
    state[1] = @truncate(u >> 32);
    state[2] = @truncate(u >> 64);
    const um: u64 = @bitCast(cpu.mult);
    state[3] = @truncate(um);
    state[4] = @truncate(um >> 32);
    state[5] = cpu.pc;
    state[6] = total_steps;
    state[7] = @intFromBool(halted);
    for (cpu.memory, 0..) |word, i| {
        state[8 + i] = word;
    }
}

/// Load Initial Orders and prepare the CPU. Must be called before step().
/// use_io1: 0 = Initial Orders 2 (default), 1 = Initial Orders 1.
export fn init(tape_len: u32, use_io1: u32) void {
    cpu = .{};
    reader = .{ .tape = tape_buf[0..tape_len] };
    out = .{};
    sec_tape = .{};
    halted = false;
    tape_exhausted = false;
    total_steps = 0;
    const orders = if (use_io1 != 0) &edsac.initial_orders_1 else &edsac.initial_orders_2;
    for (orders, 0..) |word, i| cpu.memory[i] = word;
}

/// Execute up to max_steps instructions (0 = run to completion).
/// Returns the number of steps executed. Check state[7] for halt status.
export fn step(max_steps: u32) u32 {
    if (halted) return 0;
    const result = edsac.run(&cpu, &reader, &out, &wasmOutput, &sec_tape, max_steps);
    total_steps += result.steps;
    if (result.halted) halted = true;
    if (result.tape_exhausted) tape_exhausted = true;
    return result.steps;
}

export fn isHalted() u32 {
    return @intFromBool(halted);
}

export fn isTapeExhausted() u32 {
    return @intFromBool(tape_exhausted);
}

export fn getTotalSteps() u32 {
    return total_steps;
}

export fn getPC() u32 {
    return cpu.pc;
}

/// Zero all memory and registers. Does not load Initial Orders.
export fn clearMachine() void {
    cpu = .{};
    out = .{};
    sec_tape = .{};
    halted = true;
    tape_exhausted = false;
    total_steps = 0;
}

export fn getSecTapeLen() u32 {
    return @intCast(sec_tape.write_pos);
}

/// Resume execution from a halt without modifying any state.
export fn resumeExec() void {
    halted = false;
}

/// Operator telephone dial input: adds 2*digit (0 counts as 10) to the
/// accumulator (as a short-word value) and resumes execution.
export fn dialInput(digit: u32) void {
    if (!halted) return;
    const value: u32 = if (digit == 0) 10 else digit;
    cpu.acc +%= @as(i72, @intCast(value * 2)) << 54;
    cpu.norm();
    halted = false;
}
