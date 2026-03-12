#include "runtime.h"
#include "uart.h"

static char hello[] = "Hello, CPU!";

void init() {
    return;
}

void always() {
    for (int i=0; hello[i] != '\0'; ++i) {
        uart_putc(hello[i]);
    }
    uart_putc('\n');
}