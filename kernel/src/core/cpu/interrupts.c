void asm_lidtl(const void *idtr) { asm volatile("lidtq (%0)" ::"r"(idtr)); }
