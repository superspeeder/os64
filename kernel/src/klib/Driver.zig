const SysInfo = @import("SysInfo.zig");

fn defaultLoad(_: *anyopaque, _: *const SysInfo) anyerror!void {}
fn defaultUnload(_: *anyopaque, _: *const SysInfo) anyerror!void {}

pub const VTable = struct {
    load: *const fn (*anyopaque, *const SysInfo) anyerror!void = defaultLoad,
    unload: *const fn (*anyopaque, *const SysInfo) anyerror!void = defaultUnload,
};

name: []const u8,
vtable: *const VTable,
ptr: *anyopaque,
