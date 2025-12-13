void port_out_byte(unsigned short port, unsigned char data) {
    asm ("out %%al, %%dx" :: "a"(data), "d"(port));
}

unsigned char port_in_byte(unsigned short port) {
    unsigned char result;
    asm volatile ("in %%dx, %%al" : "=a"(result) : "d"(port));
    return result;
}