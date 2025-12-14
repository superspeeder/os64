const std = @import("std");

const default_log_out = std.Io.Writer.Discarding.init(&.{});
var writer: std.Io.Writer = default_log_out.writer;

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    writer.print("[{s}] - {s} - ", .{ @tagName(level), @tagName(scope) }) catch {
        return;
    };
    writer.print(format, args) catch {
        return;
    };
    writer.writeByte('\n') catch {
        return;
    };
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
    errdefer hcf();

    try writer.writeAll("[PANIC] ");
    if (first_trace_addr) |addr| {
        try writer.writeAll("(0x");
        try writer.printInt(addr, 16, .lower, .{
            .width = 16,
            .fill = '0',
            .alignment = .right,
        });
        _ = try writer.write(") ");
    }
    try writer.writeAll(msg);
    hcf();
}
