const interrupts = @import("../cpu/int.zig");
const ports = @import("../cpu/ports.zig");

const std = @import("std");

var tick: u64 = 0;

pub fn init(freq: u32) void {
    interrupts.register_interrupt_handler(interrupts.IRQ0, &timer_callback);

    const divisor = 1193180 / freq;
    const low: u8 = @intCast(divisor & 0xff);
    const high: u8 = @intCast((divisor >> 8) & 0xff);
    ports.byte_out(0x43, 0x36);
    ports.byte_out(0x40, low);
    ports.byte_out(0x40, high);
}

fn timer_callback(r: interrupts.Registers) callconv(.c) void {
    _ = r;
    tick += 1;
}

pub fn get_ticks() u32 {
    return tick;
}

// WARNING: CALLING EITHER FUNCTION BEFORE INITIALIZING THE TIMER DRIVER WILL CAUSE THE SYSTEM TO HALT FOREVER
pub fn sleep_until(end_ticks: u32) void {
    while (tick < end_ticks) {
        asm volatile ("hlt");
    }
}

pub fn sleep_for(delay_ticks: u32) void {
    sleep_until(tick + delay_ticks);
}
