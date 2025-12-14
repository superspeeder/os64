pub const fb = @import("framebuffer.zig");
pub const timer = @import("timer.zig");
pub const keyboard = @import("keyboard.zig");
pub const serial = @import("serial.zig");

const core = @import("core");

pub fn init(mbi: *const core.multiboot.MultibootInfo) void {
    fb.init(mbi);
    timer.init(1000);
    keyboard.init();
}
