// Paging
const std = @import("std");

const PageTableOptions = packed struct(u8) {
    present: bool,
    rw: bool,
    us: bool,
    pwt: bool,
    pcd: bool,
    accessed: bool = false,
    avl0: u1 = 0,
    ps: bool,
};

const PageTableEntry = packed struct(u64) {
    present: bool,
    rw: bool,
    us: bool,
    pwt: bool,
    pcd: bool,
    accessed: bool = false,
    avl0: u1 = 0,
    ps: bool,
    avl1: u4 = 0,
    pageaddr: u52,

    // when using this in a layer2 table, physical addr is the address of the actual page
    // in other tables, this is the address of a the next table down.
    pub fn init(flags: PageTableOptions, physical_addr: u64) PageTableEntry {
        return @as(PageTableEntry, @bitCast(@as(u64, @intCast(@as(u8, @bitCast(flags)))) | (physical_addr & 0xfffffffffffff000)));
    }
};

// Generic page table struct. All page tables are the same layout, so we can just use one struct for all
const PageTable = extern struct {
    entries: [512]PageTableEntry align(4096),

    pub fn setPage(self: *PageTable, index: usize, entry: PageTableEntry) void {
        self.entries[index] = entry;
    }
};

// if we supported 5-layer paging, we could map up to a theoretical 128 PiB, but due to addressing limitations we can't map more than 32 PiB, and due to cpu limitations we couldn't even actually map more than 4 PiB (using LA57 and 57-bit virtual addresses). However, for now we do not support 5-level paging, so this is not yet a concern.

var pml4t: *align(4096) PageTable = undefined;

var pdpt: PageTable align(4096) = undefined;
var pdts: [8]PageTable align(4096) = undefined; // should remain packed since a page table is 4096 bytes long

pub fn init(pmp4t_addr: u64) void {
    if (pmp4t_addr % 4096 != 0) {
        @panic("Misaligned level 4 page map");
    }

    pmp4t_addr = @alignCast(@as(*align(4096) PageTable, @ptrFromInt(pmp4t_addr)));

    // Identity map the first 4 GiB of physical address space
    // Instead of trying to reuse the old page table, we can just make a new one
    // VERY IMPORTANT: we have to build the pdpt table correctly here before swapping it out with the old one, or else we will get a page fault (as we would be unmapping the memory we are currently using, or worse unmapping the page table).

    zeroTable(&pdpt);
    const pto: PageTableOptions = .{
        .present = true,
        .rw = true,
        .us = false,
        .pwt = false,
        .pcd = false,
        .ps = true,
    };

    const pto2: PageTableOptions = .{
        .present = true,
        .rw = true,
        .us = false,
        .pwt = false,
        .pcd = false,
        .ps = false,
    };

    inline for (0..8) |i| {
        const pdt: *PageTable = &pdts[i];
        zeroTable(pdt);
        const gb = i << 30;
        for (0..512) |j| {
            const padd = gb | (j << 21);
            pdt.setPage(j, .init(pto, padd));
        }
        pdpt.setPage(i, .init(pto2, @intFromPtr(pdt)));
    }

    // moment of truth
    pml4t.setPage(0, .init(pto2, @intFromPtr(&pdpt)));

    // if all worked here, then we have successfully changed into the proper page table for the system.
    std.log.debug("Identity mapped first 4 GiB of memory", .{});
}

fn zeroTable(pt: *PageTable) void {
    @memset(pt.entries[0..], @as(PageTableEntry, @bitCast(@as(u64, @intCast(0)))));
}
