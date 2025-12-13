const std = @import("std");
const serial = @import("drivers/serial.zig");
const multiboot = @import("boot/multiboot.zig");
const log = @import("stdlib/log.zig");
const drivers = @import("drivers.zig");
const cpu = @import("cpu.zig");

pub export fn kernel_main(magic: u32, addr: u64) callconv(.c) noreturn {
    serial.init();
    cpu.paging.init(); // immediately setup paging properly so we don't accidentally run into anything past the current 1GiB boundary.
    cpu.int.init(); // next, initialize interrupts.

    const mbi = multiboot.loadMBI(magic, addr);

    drivers.init(&mbi);

    cpu.int.int(1);
    cpu.int.int(32);

    if (mbi.bootloader) |bname| {
        std.log.debug("Bootloader: {*}", .{bname});
    }

    if (mbi.cli) |cli| {
        std.log.debug("CLI: '{s}'", .{cli});
    }

    if (mbi.biosdev) |biosdev| {
        std.log.debug("Bios boot device: {d} (part {x:08}, subpart {x:08})", .{ biosdev.bios_dev, biosdev.partition, biosdev.subpartition });
    }

    std.log.debug("Low memory: {d} KiB", .{mbi.meminfo.mem_lower_kb});
    std.log.debug("Upper memory: {d} KiB", .{mbi.meminfo.mem_upper_kb});

    for (mbi.mmap.entries) |mmap_entry| {
        std.log.debug("memory map entry: (start 0x{x:016}, len 0x{x:016}, type: {s})", .{ mmap_entry.addr, mmap_entry.len, @tagName(mmap_entry.type_) });
    }

    const xdivisor = mbi.framebuffer.width / 256;
    const ydivisor = mbi.framebuffer.height / 256;

    std.log.debug("fbdiv {d}, {d}", .{ xdivisor, ydivisor });
    std.log.debug("fbaddr {*}", .{mbi.framebuffer.buffer});

    std.log.debug("pml4t: 0x{x:016}", .{cpu.paging.get_pml4t_addr()});

    for (0..256) |j| {
        for (0..256) |i| {
            for (0..xdivisor) |x| {
                for (0..ydivisor) |y| {
                    drivers.fb.put_pixel(@intCast(i * xdivisor + x), @intCast(j * ydivisor + y), @intCast(0xff | (i << 8) | (j << 16)));
                }
            }
        }
    }

    std.log.debug("Test", .{});

    while (true) {
        //        asm volatile ("hlt");
    }
}

pub const panic = std.debug.FullPanic(log.panicFn);
pub const std_options: std.Options = .{
    .logFn = log.logFn,
    .log_level = .debug,
    // Segfaults aren't real (reality: kernel has priviledge level 0 so cannot segfault since we map 0-0xffffffff as code)
    .enable_segfault_handler = false,
};
