#include "runtime.h"
#include "seg7.h"
#include "buttons.h"

static uint32_t counter = 0;

void init(void) {
    const char *msg = "Begin tiggle led";
    for (int i=0; msg[i] != '\0'; i++) {
        uart_putc((uint8_t)msg[i]);
    }
    uart_putc('\n');
}

void always(void) {
    // Test hardware edge-capture path.
    if (btn_edge_pending(0)) {
        btn_clear_edge(0);
        counter++;
    }
    seg7_show_u32(counter);
}