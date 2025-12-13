// Basic kernel physical memory allocator

// Due to the minimum allocation size of 4 KiB, this should

const std = @import("std");

const memory_size = 0x100000000;
var memory_block: [*]u8 = @ptrFromInt(0x100000000);
pub var allocator: std.heap.FixedBufferAllocator = undefined;

pub fn init() void {
    allocator = std.heap.FixedBufferAllocator.init(memory_block[0..memory_size]);
}
