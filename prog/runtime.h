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

/*
 * Multi-device GPIO input (buttons)
 * Device n base: BTN_BASE_ADDR + n * BTN_STRIDE
 */
#define BTN_BASE_ADDR        0x10000100u
#define BTN_DEV_COUNT        4u
#define BTN_STRIDE           0x10u
#define BTN_REG_DATA_OFF     0x00u /* bit per button, read-only */
#define BTN_REG_EDGE_OFF     0x04u /* edge-capture, write-1-to-clear */

/*
 * Multi-device GPIO output (LED)
 * Device n base: LED_BASE_ADDR + n * LED_STRIDE
 */
#define LED_BASE_ADDR        0x10000200u
#define LED_DEV_COUNT        4u
#define LED_STRIDE           0x10u
#define LED_REG_DATA_OFF     0x00u /* bit per LED, read/write */
#define LED_REG_SET_OFF      0x04u /* write-1-to-set bits */
#define LED_REG_CLR_OFF      0x08u /* write-1-to-clear bits */

/* Legacy aliases for device 0 compatibility */
#define BTN_DATA             (BTN_BASE_ADDR + BTN_REG_DATA_OFF)
#define BTN_EDGE             (BTN_BASE_ADDR + BTN_REG_EDGE_OFF)
#define LED_DATA             (LED_BASE_ADDR + LED_REG_DATA_OFF)
#define LED_SET              (LED_BASE_ADDR + LED_REG_SET_OFF)
#define LED_CLR              (LED_BASE_ADDR + LED_REG_CLR_OFF)

#define REG32(addr)          (*(volatile uint32_t *)(uintptr_t)(addr))

#define mmio_read32(addr)    REG32(addr)
#define mmio_write32(addr,v) (REG32(addr) = (uint32_t)(v))

static inline uintptr_t btn_base(uint32_t btn_dev)
{
	return (uintptr_t)BTN_BASE_ADDR + (uintptr_t)(btn_dev * BTN_STRIDE);
}

static inline uintptr_t led_base(uint32_t led_dev)
{
	return (uintptr_t)LED_BASE_ADDR + (uintptr_t)(led_dev * LED_STRIDE);
}

static inline uint32_t btn_read(uint32_t btn_dev)
{
	if (btn_dev >= BTN_DEV_COUNT) {
		return 0u;
	}
	return mmio_read32(btn_base(btn_dev) + BTN_REG_DATA_OFF);
}

static inline uint32_t btn_read_edge(uint32_t btn_dev)
{
	if (btn_dev >= BTN_DEV_COUNT) {
		return 0u;
	}
	return mmio_read32(btn_base(btn_dev) + BTN_REG_EDGE_OFF);
}

static inline void btn_clear_edge(uint32_t btn_dev, uint32_t mask)
{
	if (btn_dev >= BTN_DEV_COUNT) {
		return;
	}
	mmio_write32(btn_base(btn_dev) + BTN_REG_EDGE_OFF, mask);
}

static inline int btn_is_pressed(uint32_t btn_dev, uint32_t bit_idx)
{
	if (bit_idx >= 32u) {
		return 0;
	}
	return ((btn_read(btn_dev) >> bit_idx) & 0x1u) ? 1 : 0;
}

static inline uint32_t led_read(uint32_t led_dev)
{
	if (led_dev >= LED_DEV_COUNT) {
		return 0u;
	}
	return mmio_read32(led_base(led_dev) + LED_REG_DATA_OFF);
}

static inline void led_write(uint32_t led_dev, uint32_t value)
{
	if (led_dev >= LED_DEV_COUNT) {
		return;
	}
	mmio_write32(led_base(led_dev) + LED_REG_DATA_OFF, value);
}

static inline void led_set_bits(uint32_t led_dev, uint32_t mask)
{
	if (led_dev >= LED_DEV_COUNT) {
		return;
	}
	mmio_write32(led_base(led_dev) + LED_REG_SET_OFF, mask);
}

static inline void led_clear_bits(uint32_t led_dev, uint32_t mask)
{
	if (led_dev >= LED_DEV_COUNT) {
		return;
	}
	mmio_write32(led_base(led_dev) + LED_REG_CLR_OFF, mask);
}

static inline void led_toggle_bits(uint32_t led_dev, uint32_t mask)
{
	uint32_t cur;

	if (led_dev >= LED_DEV_COUNT) {
		return;
	}
	cur = led_read(led_dev);
	led_write(led_dev, cur ^ mask);
}

extern void init();
extern void always();

#endif /* RUNTIME_H */
