const std = @import("std");
const core = @import("core");
const klib = @import("klib");
const drivers = @import("drivers");

// Get the address of the 4th layer page table
extern fn get_pml4t_addr() callconv(.c) u64;

pub export fn kernel_main(magic: u32, addr: u64) callconv(.c) noreturn {
    drivers.serial.init(); // initialize the serial driver so that we can get debug output.
    core.cpu.paging.init(get_pml4t_addr()); // immediately setup paging properly so we don't accidentally run into anything past the current 1GiB boundary.
    core.cpu.int.init(); // next, initialize interrupts.
    // Load the multiboot info
    const mbi = core.multiboot.loadMBI(magic, addr);

    // Initialize the kernel library (sets up important things like memory allocation).
    klib.init();

    // Initialize drivers.
    drivers.init(&mbi);

    // Output some debug information about the boot environment.
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

    // Draw a gradient to the screen.
    const xdivisor = mbi.framebuffer.width / 256;
    const ydivisor = mbi.framebuffer.height / 256;

    for (0..256) |j| {
        for (0..256) |i| {
            for (0..xdivisor) |x| {
                for (0..ydivisor) |y| {
                    drivers.fb.put_pixel(@intCast(i * xdivisor + x), @intCast(j * ydivisor + y), @intCast(0xff | (i << 8) | (j << 16)));
                }
            }
        }
    }

    // Make the CPU sit forever from now on.
    while (true) {
        asm volatile ("hlt");
    }
}

/// Zig configuration:
pub const panic = std.debug.FullPanic(klib.log.panicFn);
pub const std_options: std.Options = .{
    .logFn = klib.log.logFn,
    .log_level = .debug,
    // Segfaults aren't real (reality: kernel has priviledge level 0 so cannot segfault since we map 0-0xffffffff as code)
    .enable_segfault_handler = false,
};
