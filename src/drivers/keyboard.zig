const int = @import("../cpu/int.zig");
const ports = @import("../cpu/ports.zig");
const std = @import("std");

const sc_ascii: []const u8 = [_]u8{ '?', '?', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '?', '?', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', '?', '?', 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', '`', '?', '\\', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '/', '?', '?', '?', ' ' };
const sc_name = [_][]const u8{ "ERROR", "Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace", "Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "Enter", "Lctrl", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "`", "LShift", "\\", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "RShift", "Keypad *", "LAlt", "Spacebar" };
const SC_MAX = 57;

fn keyboard_callback(r: int.Registers) callconv(.c) void {
    const scancode = ports.byte_in(0x60);
    if (scancode > SC_MAX) {
        std.log.info("Unknown Key Scancode: {d}", .{scancode});
        return;
    }

    std.log.info("Key Pressed: {s}", .{sc_name[scancode]});

    _ = r;
}

pub fn init() void {
    int.register_interrupt_handler(int.IRQ1, &keyboard_callback);
}
