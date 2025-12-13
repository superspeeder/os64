const mb = @import("boot/multiboot.zig");
pub const fb = @import("drivers/framebuffer.zig");
pub const timer = @import("drivers/timer.zig");
pub const keyboard = @import("drivers/keyboard.zig");

pub fn init(mbi: *const mb.MultibootInfo) void {
    fb.init(mbi);
    timer.init(1000);
    keyboard.init();
}
