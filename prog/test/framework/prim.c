#include "runtime.h"

#define MAX_N 50

unsigned char is_composite[MAX_N + 1];
unsigned prims[MAX_N / 2 + 1];
unsigned prim_count = 0;

void uart_print_uint(unsigned x);

void init(void) {
    prim_count = 0;
    for (unsigned i=0; i<=MAX_N; ++i) {
        is_composite[i] = 0;
    }

    for (unsigned i=2; i<=MAX_N; ++i) {
        if (!is_composite[i]) {
            prims[prim_count++] = i;
        }
        for (unsigned j=0; j<prim_count && i * prims[j] <= MAX_N; ++j) {
            is_composite[i * prims[j]] = 1;
            if (i % prims[j] == 0) {
                break;
            }
        }
    }
    seg7_show_u32(prim_count);

    uart_puts("Primes is ready\n");

}

void always(void) {
    if (btn_edge_pending(0)) {
        btn_clear_edge(0);
        for (unsigned i=0; i<prim_count; ++i) {
            uart_print_uint(prims[i]);
            uart_putc('\n');
        }
    }
}

void uart_print_uint(unsigned x) {
    unsigned cur_digit = x % 10;
    unsigned next_x = x / 10;
    if (next_x > 0) {
        uart_print_uint(next_x);
    }
    uart_putc(cur_digit + '0');
}