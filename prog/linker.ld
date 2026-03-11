/*******************************************************************************
 * Linker script for RV32I single-cycle CPU
 * 
 * Memory layout:
 *   IMEM: 0x00000000 - 0x00000FFF (4KB instruction memory)
 *   DRAM: 0x00001000 - 0x00001FFF (4KB data RAM, non-overlapping with IMEM)
 *   MMIO: 0x10000000 - 0x10000FFF (4KB MMIO region for peripherals)
 ******************************************************************************/

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DRAM (rwx) : ORIGIN = 0x00001000, LENGTH = 4K
    MMIO (rw)  : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
    /* Code section starts at address 0 */
    .text : {
        *(.text._start)
        *(.text*)
        . = ALIGN(4);
    } > IMEM

    /* Read-only data */
    .rodata : {
        *(.rodata*)
        . = ALIGN(4);
    } > IMEM

    /* Initialized data */
    .data : {
        __data_load_start = LOADADDR(.data);
        __data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        __data_end = .;
    } > DRAM AT > IMEM

    /* Uninitialized data */
    .bss : {
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
