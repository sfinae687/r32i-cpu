#include "runtime.h"

void init() {
    int a, b;
    a = uart_getc();
    b = uart_getc();
    seg7_show_u32(a + b);
}