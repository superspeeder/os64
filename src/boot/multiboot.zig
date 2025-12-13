const std = @import("std");

const MultibootTagHeader = extern struct {
    type_: u16,
    flags: u16,
    size: u32,
};

pub const FramebufferInfo = extern struct {
    buffer: [*]u32, // yay no more padding needed here (64 bit means this just works)
    pitch: u32,
    width: u32,
    height: u32,
    bpp: u8,
};

pub const BasicMemInfo = extern struct {
    mem_lower_kb: u32,
    mem_upper_kb: u32,
};

pub const MemoryMapInfo = struct {
    entries: []MemoryMapEntry,
};

const MultibootMMapHeader = extern struct {
    type_: u32,
    size: u32,
    entry_size: u32,
    entry_version: u32,
};

pub const MemoryMapEntryType = enum(u32) {
    available = 1,
    reserved = 2,
    acpi_reclaimable = 3,
    nvs = 4,
    badram = 5,
};

pub const MemoryMapEntry = extern struct {
    addr: u64,
    len: u64,
    type_: MemoryMapEntryType,
    zero: u32,
};

pub const BiosBootDevice = extern struct {
    bios_dev: u32,
    partition: u32,
    subpartition: u32,
};

fn MbTagStruct(data: type) type {
    return extern struct {
        header: MultibootTagHeader,
        data: data,

        pub fn from(tagptr: *MultibootTagHeader) @This() {
            return @as(*align(4) @This(), @ptrCast(tagptr)).*;
        }
    };
}

const MBFBR = MbTagStruct(FramebufferInfo);
const MBBMI = MbTagStruct(BasicMemInfo);
const MBBDEV = MbTagStruct(BiosBootDevice);

pub const MultibootInfo = struct {
    framebuffer: FramebufferInfo,
    mmap: MemoryMapInfo,
    meminfo: BasicMemInfo,
    biosdev: ?BiosBootDevice = null,
    cli: ?[*:0]const u8 = null,
    bootloader: ?[*:0]const u8 = null,
};

pub fn loadMBI(magic: u32, addr: u64) MultibootInfo {
    std.log.debug("Loading mbi", .{});

    if (magic != 0x36d76289) {
        std.log.debug("Magic does not match", .{});
        @panic("Magic does not match\n");
    }

    if (addr & 7 != 0) {
        std.log.debug("Unaligned mbi", .{});
        @panic("Unaligned mbi\n");
    }

    var tag: *MultibootTagHeader = @ptrFromInt(addr + 8);
    var mbi: MultibootInfo = undefined;

    while (tag.type_ != 0) {
        std.log.debug("read tag {d}", .{tag.type_});
        if (tag.type_ == 8) {
            // write_serial_string("fb tag\n");
            const mbfbr = MBFBR.from(tag);
            mbi.framebuffer = mbfbr.data;
        } else if (tag.type_ == 6) {
            const header = @as(*MultibootMMapHeader, @ptrCast(tag)).*;
            const num_entries = (header.size - @sizeOf(MultibootMMapHeader)) / header.entry_size;
            const pentries = @as([*]MemoryMapEntry, @ptrFromInt(@intFromPtr(tag) + @sizeOf(MultibootMMapHeader)));
            mbi.mmap = .{ .entries = pentries[0..num_entries] };
        } else if (tag.type_ == 4) {
            const mbbmi = MBBMI.from(tag);
            mbi.meminfo = mbbmi.data;
        } else if (tag.type_ == 5) {
            const mbbdev = MBBDEV.from(tag);
            mbi.biosdev = mbbdev.data;
        } else if (tag.type_ == 1) {
            const str: [*:0]const u8 = @ptrFromInt(@intFromPtr(tag) + @sizeOf(MultibootTagHeader));
            mbi.cli = str;
        } else if (tag.type_ == 2) {
            const str: [*:0]const u8 = @ptrFromInt(@intFromPtr(tag) + @sizeOf(MultibootTagHeader));
            mbi.bootloader = str;
        }

        tag = @ptrCast(@alignCast(@as([*]u8, @ptrCast(tag)) + ((tag.size + 7) & ~@as(u32, 7))));
    }

    return mbi;
}
