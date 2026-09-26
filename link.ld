ENTRY(start)
SECTIONS {
    . = 0xD1A87F;
    .text : { *(.text) *(.rodata) *(.data) }
    .bss 0xD031F6 (NOLOAD) : {
        bss_start = .;
        *(.bss)
    }
    bss_size = SIZEOF(.bss);
    ASSERT(SIZEOF(.text) < 60000, "Program too large")
    ASSERT(SIZEOF(.bss) < 8400, "Scratch space exhausted")
}
