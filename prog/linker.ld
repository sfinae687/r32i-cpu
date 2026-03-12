/*******************************************************************************
 * Linker script for RV32I single-cycle CPU
 * 
 * Memory layout:
 *   IMEM: 0x00000000 - 0x00001FFF (8KB instruction memory)
 *   DRAM: 0x00002000 - 0x00003FFF (8KB data RAM, non-overlapping with IMEM)
 *   MMIO: 0x10000000 - 0x10000FFF (4KB MMIO region for peripherals)
 ******************************************************************************/

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    DRAM (rwx) : ORIGIN = 0x00002000, LENGTH = 8K
    MMIO (rw)  : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
    /* Code section starts at address 0 */
    .text : {
        __text_start = .;
        *(.text._start)
        *(.text*)
        . = ALIGN(4);
        __text_end = .;
    } > IMEM

    /* Read-only data */
    .rodata : {
        __rodata_start = .;
        *(.rodata*)
        . = ALIGN(4);
        __rodata_end = .;
    } > IMEM

    /* Initialized data */
    .data : {
        . = ALIGN(4);
        __data_load_start = LOADADDR(.data);
        __data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        __data_end = .;
        __data_load_end = __data_load_start + SIZEOF(.data);
    } > DRAM AT > IMEM

    /* Uninitialized data */
    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DRAM

    /* Stack grows down from top of RAM */
    . = ORIGIN(DRAM) + LENGTH(DRAM);
    __stack_top = .;
}
