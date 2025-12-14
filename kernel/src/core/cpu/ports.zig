extern fn port_out_byte(port: u16, data: u8) callconv(.c) void;
extern fn port_in_byte(port: u16) callconv(.c) u8;
pub const byte_out = port_out_byte;
pub const byte_in = port_in_byte;
