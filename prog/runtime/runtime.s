################################################################################
# runtime.s - Startup runtime for RV32I single-cycle CPU
#
# Responsibilities:
#   1) Initialize stack pointer
#   2) Copy initialized .data from IMEM load image to DRAM VMA
#   3) Zero .bss
#   4) Call init() once, then call always() in an infinite loop
################################################################################

    .section .text._start
    .global _start

_start:
    # Stack top from linker script
    la   sp, __stack_top

    # ------------------------------------------------------------------------
    # Copy .data: [__data_load_start, __data_load_end) -> [__data_start, __data_end)
    # ------------------------------------------------------------------------
    la   t0, __data_load_start
    la   t1, __data_start
    la   t2, __data_end

1:
    bgeu t1, t2, 2f
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j    1b

    # ------------------------------------------------------------------------
    # Clear .bss: [__bss_start, __bss_end)
    # ------------------------------------------------------------------------
2:
    la   t0, __bss_start
    la   t1, __bss_end

3:
    bgeu t0, t1, 4f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    3b

    # ------------------------------------------------------------------------
    # Application entry hooks
    # ------------------------------------------------------------------------
4:
    jal  ra, init

5:
    jal  ra, always
    j    5b

    # ------------------------------------------------------------------------
    # Weak defaults if user code does not provide init/always.
    # ------------------------------------------------------------------------
    .section .text
    .weak init
init:
    jalr zero, 0(ra)

    .weak always
always:
    jalr zero, 0(ra)

