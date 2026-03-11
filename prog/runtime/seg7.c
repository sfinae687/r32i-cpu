#include "runtime.h"

static const uint8_t seg7_digit_map[16] = {
	0x3Fu, /* 0 */
	0x06u, /* 1 */
	0x5Bu, /* 2 */
	0x4Fu, /* 3 */
	0x66u, /* 4 */
	0x6Du, /* 5 */
	0x7Du, /* 6 */
	0x07u, /* 7 */
	0x7Fu, /* 8 */
	0x6Fu, /* 9 */
	0x77u, /* A */
	0x7Cu, /* b */
	0x39u, /* C */
	0x5Eu, /* d */
	0x79u, /* E */
	0x71u  /* F */
};

uintptr_t seg7_ctrl_base(uint32_t seg_ctrl)
{
	return (uintptr_t)LED_BASE_ADDR + (uintptr_t)(seg_ctrl * LED_STRIDE);
}

void seg7_ctrl_write_raw(uint32_t seg_ctrl, uint32_t raw)
{
	if (seg_ctrl >= SEG7_CTRL_COUNT) {
		return;
	}
	mmio_write32(seg7_ctrl_base(seg_ctrl) + LED_REG_DATA_OFF, raw & SEG7_MASK);
}

uint32_t seg7_ctrl_read_raw(uint32_t seg_ctrl)
{
	if (seg_ctrl >= SEG7_CTRL_COUNT) {
		return 0u;
	}
	return mmio_read32(seg7_ctrl_base(seg_ctrl) + LED_REG_DATA_OFF) & SEG7_MASK;
}

uint32_t seg7_encode_hex(uint32_t hex)
{
	if (hex < 16u) {
		return (uint32_t)seg7_digit_map[hex];
	}
	return 0u;
}

void seg7_show_hex(uint32_t seg_ctrl, uint32_t hex)
{
	seg7_ctrl_write_raw(seg_ctrl, seg7_encode_hex(hex));
}

void seg7_show_dec_digit(uint32_t seg_ctrl, uint32_t dec_digit)
{
	if (dec_digit < 10u) {
		seg7_show_hex(seg_ctrl, dec_digit);
		return;
	}
	seg7_ctrl_write_raw(seg_ctrl, 0u);
}

void seg7_show_u32(uint32_t value)
{
	uint32_t ctrl;
	uint32_t digit;
	uint32_t tmp;

	tmp = value;
	for (ctrl = 0u; ctrl < SEG7_CTRL_COUNT; ++ctrl) {
		digit = tmp % 10u;
		seg7_show_dec_digit(ctrl, digit);
		tmp = tmp / 10u;
	}
}

void seg7_clear_all(void)
{
	uint32_t ctrl;

	for (ctrl = 0u; ctrl < SEG7_CTRL_COUNT; ++ctrl) {
		seg7_ctrl_write_raw(ctrl, 0u);
	}
}
