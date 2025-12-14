const std = @import("std");

var writer: std.Io.Writer = std.Io.Writer.Discarding;

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    writer.print("[{s}] - {s} - ", .{ @tagName(level), @tagName(scope) });
    writer.print(format, args);
    writer.writeByte('\n');
}

pub fn setLogOutput(output: std.Io.Writer) void {
    writer = output;
}

// turn off interrupts and halt the cpu for eternity
fn hcf() noreturn {
    //asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panicFn(msg: []const u8, first_trace_addr: ?usize) noreturn {
    try writer.writeAll("[PANIC] ") catch |e| {
        _ = e;
    };
    if (first_trace_addr) |addr| {
        try writer.writeAll("(0x") catch |e| {
            _ = e;
        };
        try writer.printInt(addr, 16, .lower, .{
            .width = 16,
            .fill = '0',
            .alignment = .right,
        }) catch |e| {
            _ = e;
        };
        try writer.write(") ") catch |e| {
            _ = e;
        };
    }
    try writer.writeAll(msg) catch |e| {
        _ = e;
    };

    hcf();
}
