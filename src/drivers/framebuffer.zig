const mb = @import("../boot/multiboot.zig");

pub const FramebufferInfo = mb.FramebufferInfo;
var framebuffer: FramebufferInfo = undefined;

pub fn init(mbi: *const mb.MultibootInfo) void {
    framebuffer = mbi.framebuffer;
}

pub fn put_pixel(x: u32, y: u32, color: u32) void {
    framebuffer.buffer[x * (framebuffer.bpp / 32) + y * (framebuffer.pitch / 4)] = color;
}
