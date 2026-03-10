#ifndef BUTTONS_H
#define BUTTONS_H

#include <stdint.h>

static inline uintptr_t btn_ctrl_base(uint32_t btn_ctrl)
{
	return (uintptr_t)BTN_BASE_ADDR + (uintptr_t)(btn_ctrl * BTN_STRIDE);
}

static inline uint32_t btn_ctrl_read(uint32_t btn_ctrl)
{
	if (btn_ctrl >= BTN_DEV_COUNT) {
		return 0u;
	}
	return mmio_read32(btn_ctrl_base(btn_ctrl) + BTN_REG_DATA_OFF);
}

static inline uint32_t btn_ctrl_read_edge(uint32_t btn_ctrl)
{
	if (btn_ctrl >= BTN_DEV_COUNT) {
		return 0u;
	}
	return mmio_read32(btn_ctrl_base(btn_ctrl) + BTN_REG_EDGE_OFF);
}

static inline void btn_ctrl_clear_edge(uint32_t btn_ctrl, uint32_t mask)
{
	if (btn_ctrl >= BTN_DEV_COUNT) {
		return;
	}
	mmio_write32(btn_ctrl_base(btn_ctrl) + BTN_REG_EDGE_OFF, mask);
}

static inline uint32_t btn_ctrl_of(uint32_t btn_idx)
{
	return btn_idx / BTN_BITS_PER_DEV;
}

static inline uint32_t btn_bit_of(uint32_t btn_idx)
{
	return btn_idx % BTN_BITS_PER_DEV;
}

static inline int btn_read(uint32_t btn_idx)
{
	uint32_t ctrl;
	uint32_t bit;

	if (btn_idx >= BTN_COUNT) {
		return 0;
	}
	ctrl = btn_ctrl_of(btn_idx);
	bit = btn_bit_of(btn_idx);
	return ((btn_ctrl_read(ctrl) >> bit) & 0x1u) ? 1 : 0;
}

static inline int btn_edge_pending(uint32_t btn_idx)
{
	uint32_t ctrl;
	uint32_t bit;

	if (btn_idx >= BTN_COUNT) {
		return 0;
	}
	ctrl = btn_ctrl_of(btn_idx);
	bit = btn_bit_of(btn_idx);
	return ((btn_ctrl_read_edge(ctrl) >> bit) & 0x1u) ? 1 : 0;
}

static inline void btn_clear_edge(uint32_t btn_idx)
{
	uint32_t ctrl;
	uint32_t bit;

	if (btn_idx >= BTN_COUNT) {
		return;
	}
	ctrl = btn_ctrl_of(btn_idx);
	bit = btn_bit_of(btn_idx);
	btn_ctrl_clear_edge(ctrl, (uint32_t)1u << bit);
}

#endif /* BUTTONS_H */
