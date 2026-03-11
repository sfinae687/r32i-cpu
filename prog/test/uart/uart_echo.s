################################################################################
# uart_echo.s - UART RX/TX echo test for RV32I CPU
#
# Behavior:
#   - Poll UART_STATUS.rx_valid
#   - Read one byte from UART_RXDATA when available
#   - Write it back to UART_TXDATA (echo)
#   - If received '\r', also send '\n'
################################################################################

    .section .text._start
    .global _start

_start:
    # Stack top (DRAM 0x00001000-0x00001FFF)
    lui sp, 0x00002

    # UART base: 0x10000000
    lui t0, 0x10000

main_loop:
    jal  ra, uart_getc          # a0 <- received byte
    jal  ra, uart_putc          # echo back

    # Optional CRLF normalization for serial terminals
    addi t1, zero, 13           # '\r'
    bne  a0, t1, main_loop
    addi a0, zero, 10           # '\n'
    jal  ra, uart_putc
    j    main_loop

uart_putc:
wait_tx_ready:
    lw   t2, 8(t0)              # UART_STATUS
    andi t2, t2, 1              # tx_ready bit
    beq  t2, zero, wait_tx_ready
    sb   a0, 0(t0)              # UART_TXDATA
    jalr zero, 0(ra)

uart_getc:
wait_rx_valid:
    lw   t2, 8(t0)              # UART_STATUS
    andi t2, t2, 2              # rx_valid bit
    beq  t2, zero, wait_rx_valid
    lbu  a0, 4(t0)              # UART_RXDATA
    jalr zero, 0(ra)

    .end
