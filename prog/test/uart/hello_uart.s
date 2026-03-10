################################################################################
# hello_uart.s - UART Test Program for RV32I CPU
#
# NOTE:
#   This CPU uses separate IMEM/DMEM interfaces (Harvard style). To avoid
#   reading constants from IMEM via DMEM, this test sends immediate bytes.
################################################################################

    .section .text._start
    .global _start

_start:
    # Stack top (4KB RAM)
    lui sp, 0x00001

    # UART base: 0x10000000
    lui t0, 0x10000

main_loop:
    addi a0, zero, 'H'
    jal  ra, uart_putc
    addi a0, zero, 'e'
    jal  ra, uart_putc
    addi a0, zero, 'l'
    jal  ra, uart_putc
    addi a0, zero, 'l'
    jal  ra, uart_putc
    addi a0, zero, 'o'
    jal  ra, uart_putc
    addi a0, zero, ','
    jal  ra, uart_putc
    addi a0, zero, ' '
    jal  ra, uart_putc
    addi a0, zero, 'U'
    jal  ra, uart_putc
    addi a0, zero, 'A'
    jal  ra, uart_putc
    addi a0, zero, 'R'
    jal  ra, uart_putc
    addi a0, zero, 'T'
    jal  ra, uart_putc
    addi a0, zero, '?'
    jal  ra, uart_putc
    addi a0, zero, 10
    jal  ra, uart_putc

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

    .end
