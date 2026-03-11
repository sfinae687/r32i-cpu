#ifndef UART_H
#define UART_H

#include <stdint.h>

#define UART_STATUS_TX_READY   (1u << 0)
#define UART_STATUS_RX_VALID   (1u << 1)

#define UART_CTRL_TX_IRQ_EN    (1u << 0)
#define UART_CTRL_RX_IRQ_EN    (1u << 1)

void uart_set_baud_div(uint32_t div);
void uart_set_ctrl(uint32_t ctrl);
uint32_t uart_get_status(void);

int uart_tx_ready(void);
int uart_rx_valid(void);

void uart_putc(uint8_t ch);
int uart_getc_nonblock(uint8_t *out);
uint8_t uart_getc(void);
void uart_puts(const char *s);

void uart_init(uint32_t baud_div);

#endif /* UART_H */
