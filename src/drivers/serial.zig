const std = @import("std");
const ports = @import("../cpu/ports.zig");

pub const PORT = 0x3f8;

fn is_transmit_empty() bool {
    return (ports.byte_in(PORT + 5) & 0x20) == 0;
}

pub fn write_serial(a: u8) void {
    while (is_transmit_empty()) _ = 0;

    ports.byte_out(PORT, a);
}

pub fn write_serial_string(str: []const u8) void {
    for (str) |c| {
        write_serial(c);
    }
}

pub fn write_serial_string_opt(comptime str: []const u8) void {
    inline for (str) |c| {
        write_serial(c);
    }
}

pub fn init() void {
    ports.byte_out(PORT + 1, 0x00);
    ports.byte_out(PORT + 3, 0x80);
    ports.byte_out(PORT + 0, 0x03);
    ports.byte_out(PORT + 1, 0x00);
    ports.byte_out(PORT + 3, 0x03);
    ports.byte_out(PORT + 2, 0xC7);
    ports.byte_out(PORT + 4, 0x0B);
    ports.byte_out(PORT + 4, 0x1E);
    ports.byte_out(PORT + 0, 0xAE);
    if (ports.byte_in(PORT + 0) != 0xAE) {
        @panic("Serial port faulty");
    }
    ports.byte_out(PORT + 4, 0x0F);
}

fn write_hex_dig(i: usize) void {
    if (i < 10) {
        write_serial('0' + @as(u8, @intCast(i)));
    } else {
        write_serial('A' + @as(u8, @intCast(i - 10)));
    }
}

pub fn write_int(i: usize) void {
    if (i >= 10) {
        write_int(i / 10);
    }
    write_serial('0' + @as(u8, @intCast(i % 10)));
}

pub fn write_hex(i: usize) void {
    if ((i & 0xF) != i) {
        write_hex(i >> 4);
    }
    write_hex_dig(i & 0xF);
}

fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
    std.debug.assert(data.len != 0);

    var consumed: usize = 0;
    const pattern = data[data.len - 1];
    const splat_len = pattern.len * splat;

    // If buffer is not empty write it first
    if (w.end != 0) {
        write_serial_string(w.buffered());
        w.end = 0;
    }

    // Now write all data except last element
    for (data[0 .. data.len - 1]) |bytes| {
        write_serial_string(bytes);
        consumed += bytes.len;
    }

    // If out patter (i.e. last element of data) is non zero len then write splat times
    switch (pattern.len) {
        0 => {},
        else => {
            for (0..splat) |_| {
                write_serial_string(pattern);
            }
        },
    }
    // Now we have to return how many bytes we consumed from data
    consumed += splat_len;
    return consumed;
}

pub fn writer(buffer: []u8) std.Io.Writer {
    return .{
        .buffer = buffer,
        .end = 0,
        .vtable = &.{
            .drain = drain,
        },
    };
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var w = writer(&.{});
    w.print(fmt, args) catch return;
}
