// interrupts
const std = @import("std");
const ports = @import("ports.zig");

const IdtGate = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u3,
    reserved: u5 = 0,
    gate_type: u4,
    always0: u1 = 0,
    dpl: u2 = 0,
    present: u1 = 1,
    offset_mid: u16,
    offset_high: u32,
    reserved2: u32 = 0,
};

const IDT_ENTRIES = 256;
var idt: [IDT_ENTRIES]IdtGate = undefined;
var idt_reg: IdtDescriptor = undefined;

const IdtDescriptor = packed struct {
    size: u16,
    offset: u64,
};

pub const Registers = extern struct {
    ds: u64,
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rdi: u64,
    rsi: u64,
    rbp: u64,
    rbx: u64,
    rdx: u64,
    rcx: u64,
    rax: u64,
    int_no: u64,
    err_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
    userrsp: u64,
    ss: u64,
};

pub fn setIdtGate(n: u32, handler: usize) void {
    idt[n].offset_low = @intCast(handler & 0xffff);
    idt[n].selector = 0x08;
    idt[n].ist = 0;
    idt[n].reserved = 0;
    idt[n].gate_type = 0xE;
    idt[n].always0 = 0;
    idt[n].dpl = 0;
    idt[n].present = 1;
    idt[n].offset_mid = @intCast((handler >> 16) & 0xffff);
    idt[n].offset_high = @intCast((handler >> 32) & 0xffffffff);
    idt[n].reserved2 = 0;
}

extern fn asm_lidtl(p: *const void) callconv(.c) void;

fn setIdt() void {
    idt_reg.offset = @intFromPtr(&idt);
    idt_reg.size = IDT_ENTRIES * @sizeOf(IdtGate) - 1;
    asm_lidtl(@ptrCast(&idt_reg));
}

pub fn int(comptime interrupt_no: u32) void {
    asm volatile ("int %[int_no]"
        :
        : [int_no] "i" (interrupt_no),
    );
}

pub fn init() void {
    isrInstall();
    asm volatile ("sti");
}

const exception_messages: [32][]const u8 = [_][]const u8{
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Into Detected Overflow",
    "Out of Bounds",
    "Invalid Opcode",
    "No Coprocessor",
    "Double Fault",
    "Coprocessor Segment Overrun",
    "Bad TSS",
    "Segment Not Present",
    "Stack Fault",
    "General Protection Fault",
    "Page Fault",
    "Unknown Interrupt",
    "Coprocessor Fault",
    "Alignment Check",
    "Machine Check",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
};

pub export fn isr_handler(r: Registers) callconv(.c) void {
    std.log.debug("received interrupt: {d} - {s}", .{ r.int_no, exception_messages[r.int_no] });
    if (r.int_no == 13) { // gpf
        // when we get a gpf, output more data and halt the cpu
        std.log.debug("rip: 0x{x:016}", .{r.rip});
        asm volatile ("hlt");
    }

    if (r.int_no == 2) {
        // nmi(big problem)
        const pa = ports.byte_in(0x92);
        const pb = ports.byte_in(0x61);
        std.log.debug("scpa: {b:08}", .{pa});
        std.log.debug("scpb: {b:08}", .{pb});
        //asm volatile ("hlt");
    }

    if (r.int_no == 14) {
        const cr2 = get_cr2();
        std.log.debug("Page fault address: {x:016}", .{cr2});
        asm volatile ("hlt");
    }
}

extern fn get_cr2() callconv(.c) u64;

pub const IRQ0 = 32;
pub const IRQ1 = 33;
pub const IRQ2 = 34;
pub const IRQ3 = 35;
pub const IRQ4 = 36;
pub const IRQ5 = 37;
pub const IRQ6 = 38;
pub const IRQ7 = 39;
pub const IRQ8 = 40;
pub const IRQ9 = 41;
pub const IRQ10 = 42;
pub const IRQ11 = 43;
pub const IRQ12 = 44;
pub const IRQ13 = 45;
pub const IRQ14 = 46;
pub const IRQ15 = 47;

pub const Isr = *const fn (r: Registers) callconv(.c) void;
var interrupt_handlers: [256]?Isr = undefined;

pub fn register_interrupt_handler(n: u8, handler: Isr) void {
    interrupt_handlers[n] = handler;
}

fn remapPic() void {
    ports.byte_out(0x20, 0x11);
    ports.byte_out(0xA0, 0x11);
    ports.byte_out(0x21, 0x20);
    ports.byte_out(0xA1, 0x28);
    ports.byte_out(0x21, 0x04);
    ports.byte_out(0xA1, 0x02);
    ports.byte_out(0x21, 0x01);
    ports.byte_out(0xA1, 0x01);
    ports.byte_out(0x21, 0x0);
    ports.byte_out(0xA1, 0x0);
}

pub export fn irq_handler(r: Registers) callconv(.c) void {
    if (r.int_no >= 40) ports.byte_out(0xA0, 0x20);
    ports.byte_out(0x20, 0x20);

    if (interrupt_handlers[r.int_no]) |handler| {
        handler(r);
    }
}

fn isrInstall() void {
    @memset(interrupt_handlers[0..], null);

    setIdtGate(0, @intFromPtr(&isr0));
    setIdtGate(1, @intFromPtr(&isr1));
    setIdtGate(2, @intFromPtr(&isr2));
    setIdtGate(3, @intFromPtr(&isr3));
    setIdtGate(4, @intFromPtr(&isr4));
    setIdtGate(5, @intFromPtr(&isr5));
    setIdtGate(6, @intFromPtr(&isr6));
    setIdtGate(7, @intFromPtr(&isr7));
    setIdtGate(8, @intFromPtr(&isr8));
    setIdtGate(9, @intFromPtr(&isr9));
    setIdtGate(10, @intFromPtr(&isr10));
    setIdtGate(11, @intFromPtr(&isr11));
    setIdtGate(12, @intFromPtr(&isr12));
    setIdtGate(13, @intFromPtr(&isr13));
    setIdtGate(14, @intFromPtr(&isr14));
    setIdtGate(15, @intFromPtr(&isr15));
    setIdtGate(16, @intFromPtr(&isr16));
    setIdtGate(17, @intFromPtr(&isr17));
    setIdtGate(18, @intFromPtr(&isr18));
    setIdtGate(19, @intFromPtr(&isr19));
    setIdtGate(20, @intFromPtr(&isr20));
    setIdtGate(21, @intFromPtr(&isr21));
    setIdtGate(22, @intFromPtr(&isr22));
    setIdtGate(23, @intFromPtr(&isr23));
    setIdtGate(24, @intFromPtr(&isr24));
    setIdtGate(25, @intFromPtr(&isr25));
    setIdtGate(26, @intFromPtr(&isr26));
    setIdtGate(27, @intFromPtr(&isr27));
    setIdtGate(28, @intFromPtr(&isr28));
    setIdtGate(29, @intFromPtr(&isr29));
    setIdtGate(30, @intFromPtr(&isr30));
    setIdtGate(31, @intFromPtr(&isr31));

    remapPic();

    setIdtGate(32, @intFromPtr(&irq0));
    setIdtGate(33, @intFromPtr(&irq1));
    setIdtGate(34, @intFromPtr(&irq2));
    setIdtGate(35, @intFromPtr(&irq3));
    setIdtGate(36, @intFromPtr(&irq4));
    setIdtGate(37, @intFromPtr(&irq5));
    setIdtGate(38, @intFromPtr(&irq6));
    setIdtGate(39, @intFromPtr(&irq7));
    setIdtGate(40, @intFromPtr(&irq8));
    setIdtGate(41, @intFromPtr(&irq9));
    setIdtGate(42, @intFromPtr(&irq10));
    setIdtGate(43, @intFromPtr(&irq11));
    setIdtGate(44, @intFromPtr(&irq12));
    setIdtGate(45, @intFromPtr(&irq13));
    setIdtGate(46, @intFromPtr(&irq14));
    setIdtGate(47, @intFromPtr(&irq15));

    setIdt();
}

// TODO: Understand the fucking calling conventions for structs in x86-64 system v abi.
// TODO: decide on data layout for Registers struct (preferably so that the information pushed onto the stack by the cpu is accessible with no copies)
// TODO: setup ISRs, IRQs

extern fn isr0() callconv(.c) void;
extern fn isr1() callconv(.c) void;
extern fn isr2() callconv(.c) void;
extern fn isr3() callconv(.c) void;
extern fn isr4() callconv(.c) void;
extern fn isr5() callconv(.c) void;
extern fn isr6() callconv(.c) void;
extern fn isr7() callconv(.c) void;
extern fn isr8() callconv(.c) void;
extern fn isr9() callconv(.c) void;
extern fn isr10() callconv(.c) void;
extern fn isr11() callconv(.c) void;
extern fn isr12() callconv(.c) void;
extern fn isr13() callconv(.c) void;
extern fn isr14() callconv(.c) void;
extern fn isr15() callconv(.c) void;
extern fn isr16() callconv(.c) void;
extern fn isr17() callconv(.c) void;
extern fn isr18() callconv(.c) void;
extern fn isr19() callconv(.c) void;
extern fn isr20() callconv(.c) void;
extern fn isr21() callconv(.c) void;
extern fn isr22() callconv(.c) void;
extern fn isr23() callconv(.c) void;
extern fn isr24() callconv(.c) void;
extern fn isr25() callconv(.c) void;
extern fn isr26() callconv(.c) void;
extern fn isr27() callconv(.c) void;
extern fn isr28() callconv(.c) void;
extern fn isr29() callconv(.c) void;
extern fn isr30() callconv(.c) void;
extern fn isr31() callconv(.c) void;

extern fn irq0() callconv(.c) void;
extern fn irq1() callconv(.c) void;
extern fn irq2() callconv(.c) void;
extern fn irq3() callconv(.c) void;
extern fn irq4() callconv(.c) void;
extern fn irq5() callconv(.c) void;
extern fn irq6() callconv(.c) void;
extern fn irq7() callconv(.c) void;
extern fn irq8() callconv(.c) void;
extern fn irq9() callconv(.c) void;
extern fn irq10() callconv(.c) void;
extern fn irq11() callconv(.c) void;
extern fn irq12() callconv(.c) void;
extern fn irq13() callconv(.c) void;
extern fn irq14() callconv(.c) void;
extern fn irq15() callconv(.c) void;
