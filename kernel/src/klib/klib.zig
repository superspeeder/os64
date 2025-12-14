pub const mem = @import("mem.zig");
pub const log = @import("log.zig");
pub const SysInfo = @import("SysInfo.zig");
pub const Driver = @import("Driver.zig");

pub fn init() !void {
    mem.init();
}
