const serial = @import("../drivers/serial.zig");
const std = @import("std");

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    serial.print("[{s}] - {s} - ", .{ @tagName(level), @tagName(scope) });
    serial.print(format, args);
    serial.write_serial('\n');
}

// turn off interrupts and halt the cpu for eternity
fn hcf() noreturn {
    //asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panicFn(msg: []const u8, first_trace_addr: ?usize) noreturn {
    serial.write_serial_string_opt("[PANIC] ");
    if (first_trace_addr) |addr| {
        serial.write_serial_string_opt("(0x");
        serial.write_hex(addr);
        serial.write_serial_string_opt(") ");
    }
    serial.write_serial_string(msg);
    hcf();
}
