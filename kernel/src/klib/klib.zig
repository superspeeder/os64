pub const mem = @import("mem.zig");
pub const log = @import("log.zig");

pub fn init() !void {
    mem.init();
}
