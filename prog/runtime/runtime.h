#ifndef RUNTIME_H
#define RUNTIME_H

#include <stdint.h>

/*
 * Memory map planning for the RV32I single-cycle system.
 *
 * Address space split:
 *   0x0000_0000 - 0x0000_0FFF : Data RAM (4KB, existing dram)
 *   0x1000_0000 - 0x1000_0FFF : MMIO region (new peripherals)
 */

#define RAM_BASE_ADDR        0x00000000u
#define RAM_SIZE_BYTES       0x00001000u

#define MMIO_BASE_ADDR       0x10000000u
#define MMIO_SIZE_BYTES      0x00001000u

/* UART register block: 0x1000_0000 - 0x1000_001F */
#define UART_BASE_ADDR       0x10000000u
#define UART_TXDATA          (UART_BASE_ADDR + 0x00u) /* [7:0] write to send */
#define UART_RXDATA          (UART_BASE_ADDR + 0x04u) /* [7:0] read received */
#define UART_STATUS          (UART_BASE_ADDR + 0x08u) /* bit0:tx_ready bit1:rx_valid */
#define UART_CTRL            (UART_BASE_ADDR + 0x0Cu) /* bit0:tx_irq_en bit1:rx_irq_en */
#define UART_BAUD_DIV        (UART_BASE_ADDR + 0x10u) /* baud divider */

/* Multi-device GPIO input (buttons) */
#define BTN_BASE_ADDR        0x10000100u
#define BTN_DEV_COUNT        4u
#define BTN_STRIDE           0x10u
#define BTN_BITS_PER_DEV     32u
#define BTN_COUNT            (BTN_DEV_COUNT * BTN_BITS_PER_DEV)
#define BTN_REG_DATA_OFF     0x00u /* bit per button, read-only */
#define BTN_REG_EDGE_OFF     0x04u /* edge-capture, write-1-to-clear */

/* Multi-device GPIO output (LED / 7-seg controller registers) */
#define LED_BASE_ADDR        0x10000200u
#define LED_DEV_COUNT        4u
#define LED_STRIDE           0x10u
#define LED_BITS_PER_DEV     32u
#define LED_COUNT            (LED_DEV_COUNT * LED_BITS_PER_DEV)
#define LED_REG_DATA_OFF     0x00u /* bit per LED, read/write */
#define LED_REG_SET_OFF      0x04u /* write-1-to-set bits */
#define LED_REG_CLR_OFF      0x08u /* write-1-to-clear bits */

#define REG32(addr)          (*(volatile uint32_t *)(uintptr_t)(addr))

#define mmio_read32(addr)    REG32(addr)
#define mmio_write32(addr,v) (REG32(addr) = (uint32_t)(v))

#include "buttons.h"
#include "seg7.h"

extern void init(void);
extern void always(void);

#endif /* RUNTIME_H */
