#ifndef BUTTONS_H
#define BUTTONS_H

#include <stdint.h>

uintptr_t btn_ctrl_base(uint32_t btn_ctrl);
uint32_t btn_ctrl_read(uint32_t btn_ctrl);
uint32_t btn_ctrl_read_edge(uint32_t btn_ctrl);
void btn_ctrl_clear_edge(uint32_t btn_ctrl, uint32_t mask);

uint32_t btn_ctrl_of(uint32_t btn_idx);
uint32_t btn_bit_of(uint32_t btn_idx);

int btn_read(uint32_t btn_idx);
int btn_edge_pending(uint32_t btn_idx);
void btn_clear_edge(uint32_t btn_idx);

#endif /* BUTTONS_H */
