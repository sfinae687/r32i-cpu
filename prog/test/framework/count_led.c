#include "runtime.h"

static unsigned counter = 0;

void print_uint(unsigned n);

void init(void) {
    const char msg[] = "Begin count button 0\n";
    for (int i=0; msg[i] != 0; i++) {
        uart_putc(msg[i]);
    }
}

void always(void) {
    if (btn_edge_pending(0)) {
        btn_clear_edge(0);
        counter++;
        print_uint(counter);
        uart_putc('\n');
    }
}

void print_uint(unsigned n) {
    int cur_digit = n % 10;
    int next_n = n / 10;
    if (next_n > 0) {
        print_uint(next_n);
    }
    uart_putc('0' + cur_digit);
}