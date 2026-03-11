#include "runtime.h"

void uart_set_baud_div(uint32_t div)
{
	mmio_write32(UART_BAUD_DIV, div);
}

void uart_set_ctrl(uint32_t ctrl)
{
	mmio_write32(UART_CTRL, ctrl);
}

uint32_t uart_get_status(void)
{
	return mmio_read32(UART_STATUS);
}

int uart_tx_ready(void)
{
	return (uart_get_status() & UART_STATUS_TX_READY) ? 1 : 0;
}

int uart_rx_valid(void)
{
	return (uart_get_status() & UART_STATUS_RX_VALID) ? 1 : 0;
}

void uart_putc(uint8_t ch)
{
	while (!uart_tx_ready()) {
	}
	mmio_write32(UART_TXDATA, (uint32_t)ch);
}

int uart_getc_nonblock(uint8_t *out)
{
	if (out == (void *)0 || !uart_rx_valid()) {
		return 0;
	}
	*out = (uint8_t)(mmio_read32(UART_RXDATA) & 0xFFu);
	return 1;
}

uint8_t uart_getc(void)
{
	while (!uart_rx_valid()) {
	}
	return (uint8_t)(mmio_read32(UART_RXDATA) & 0xFFu);
}

void uart_puts(const char *s)
{
	if (s == (const char *)0) {
		return;
	}
	while (*s != '\0') {
		uart_putc((uint8_t)(*s));
		++s;
	}
}

void uart_init(uint32_t baud_div)
{
	uart_set_baud_div(baud_div);
	uart_set_ctrl(0u);
}
