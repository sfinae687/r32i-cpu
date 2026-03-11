#ifndef SEG7_H
#define SEG7_H

#include <stdint.h>

#define SEG7_CTRL_COUNT      LED_DEV_COUNT
#define SEG7_SEG_A           (1u << 0)
#define SEG7_SEG_B           (1u << 1)
#define SEG7_SEG_C           (1u << 2)
#define SEG7_SEG_D           (1u << 3)
#define SEG7_SEG_E           (1u << 4)
#define SEG7_SEG_F           (1u << 5)
#define SEG7_SEG_G           (1u << 6)
#define SEG7_SEG_DP          (1u << 7)
#define SEG7_MASK            0xFFu

uintptr_t seg7_ctrl_base(uint32_t seg_ctrl);
void seg7_ctrl_write_raw(uint32_t seg_ctrl, uint32_t raw);
uint32_t seg7_ctrl_read_raw(uint32_t seg_ctrl);

uint32_t seg7_encode_hex(uint32_t hex);
void seg7_show_hex(uint32_t seg_ctrl, uint32_t hex);
void seg7_show_dec_digit(uint32_t seg_ctrl, uint32_t dec_digit);

/*
 * Controller-to-digit mapping:
 *   controller 0 -> lowest decimal digit
 *   controller 1 -> tens
 *   controller 2 -> hundreds
 *   controller 3 -> thousands
 */
void seg7_show_u32(uint32_t value);
void seg7_clear_all(void);

#endif /* SEG7_H */
