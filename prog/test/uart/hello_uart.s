################################################################################
# hello_uart.s - UART Test Program for RV32I CPU
#
# NOTE:
#   Message bytes are stored in a normal read-only section (.rodata).
#   The program sends the string by loading one byte at a time.
################################################################################

    .section .text._start
    .global _start

_start:
    # Stack top (DRAM 0x00002000-0x00003FFF)
    lui sp, 0x00004

    # UART base: 0x10000000
    lui t0, 0x10000

main_loop:
    la   t1, hello_msg

send_loop:
    lbu  a0, 0(t1)
    beq  a0, zero, send_done
    jal  ra, uart_putc
    addi t1, t1, 1
    j    send_loop

send_done:

    # Small delay before next line
    lui t3, 0x00001
delay_loop:
    addi t3, t3, -1
    bne  t3, zero, delay_loop
    j    main_loop

uart_putc:
wait_tx_ready:
    lw   t2, 8(t0)           # UART_STATUS
    andi t2, t2, 1           # tx_ready bit
    beq  t2, zero, wait_tx_ready
    sb   a0, 0(t0)           # UART_TXDATA
    jalr zero, 0(ra)

    .section .rodata
hello_msg:
    .asciz "Hello, UART!\n"

    .end
