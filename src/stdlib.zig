pub const heap = @import("stdlib/heap.zig");
pub const log = @import("stdlib/log.zig");
const std = @import("std");

pub var allocator: std.mem.Allocator = undefined;

pub fn init() void {
    heap.init();
    allocator = heap.allocator.allocator();
}
