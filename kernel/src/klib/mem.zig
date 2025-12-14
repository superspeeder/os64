const std = @import("std");

// TODO: change this to be based on the memory map information provided by multiboot.
const memory_size = 0x100000000;
var memory_block: [*]u8 = @ptrFromInt(0x100000000);
pub var allocator: std.heap.FixedBufferAllocator = undefined;

pub fn init() void {
    allocator = std.heap.FixedBufferAllocator.init(memory_block[0..memory_size]);
}
