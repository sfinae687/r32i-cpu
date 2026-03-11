# 7-Segment Display Support - Quick Reference

## Added Features

The testbench (`sim/tb_top.v`) now includes complete support for testing 7-segment LED displays controlled by the hardware `seg7_cont` modules.

### New Verilog Tasks

**Basic Operations:**
- `seg7_read_raw(dev, value)` - Read raw 7-segment pattern
- `seg7_write_raw(dev, value)` - Write raw 7-segment pattern

**Display Functions:**
- `seg7_show_hex(dev, digit)` - Display hex digit (0-F)
- `seg7_show_dec_digit(dev, digit)` - Display decimal digit (0-9)
- `seg7_show_u32(value)` - Display 4-digit decimal number (0-9999)
- `seg7_clear_all()` - Turn off all displays

**Synchronization:**
- `seg7_wait_pattern(dev, pattern, max_cycles)` - Wait for pattern match

### Script File Commands

New script commands (use with `+SCRIPT=file`):
```
seg7_write <dev> <hex_pattern>
seg7_show_hex <dev> <hex_digit>
seg7_show_dec <dev> <dec_digit>
seg7_show_u32 <value>
seg7_wait <dev> <hex_pattern> <max_cycles>
seg7_clear
```

### Segment Encoding

7-segment patterns use bits 7:0 for segments:
- Bit 0 = A (top)
- Bit 1 = B (top-right)
- Bit 2 = C (bottom-right)
- Bit 3 = D (bottom)
- Bit 4 = E (bottom-left)
- Bit 5 = F (top-left)
- Bit 6 = G (middle)
- Bit 7 = DP (decimal point)

Common encodings:
- 0 = 0x3F
- 1 = 0x06
- 2 = 0x5B
- 3 = 0x4F
- 4 = 0x66
- 5 = 0x6D
- 6 = 0x7D
- 7 = 0x07
- 8 = 0x7F
- 9 = 0x6F

## Usage Examples

### Verilog Testbench

```verilog
// Show a counting sequence
for (int i = 0; i < 10; i++) begin
    seg7_show_dec_digit(0, i);
    repeat(100) @(posedge clk);
end

// Display a 4-digit number
seg7_show_u32(5678);
repeat(200) @(posedge clk);

// Wait for CPU-driven update
seg7_wait_pattern(0, 32'h5B, 50000);  // Wait for "2"
```

### Script File

```
wait 100
seg7_clear
wait 50
seg7_show_hex 0 5
wait 100
seg7_show_u32 1234
wait 200
seg7_clear
wait 50
finish
```

Run with:
```bash
vvp simv +SCRIPT=sim/your_script.script +NO_TIMEOUT
```

## Files Added/Modified

- **Modified:** `sim/tb_top.v` - Added 7-segment support functions
- **Created:** `sim/seg7_demo.script` - Demonstration script
- **Created:** `sim/SEG7_TESTBENCH_GUIDE.md` - Complete documentation

## Demo

A complete demonstration script is included:
```bash
cd /home/ll06/info/cpu_sources
vvp simv +SCRIPT=sim/seg7_demo.script +NO_VCD
```

This script demonstrates:
- Clearing all displays
- Displaying hex digits 0-F
- Multi-digit numbers
- Decimal digit display
- Raw pattern control
- Display clearing

## Hardware Mapping

The 4 seg7 controllers are automatically instantiated in `top_circuit.v`:
- `seg7_ctrl_inst0` → `led0` (address 0x1000_0200)
- `seg7_ctrl_inst1` → `led1` (address 0x1000_0210)
- `seg7_ctrl_inst2` → `led2` (address 0x1000_0220)
- `seg7_ctrl_inst3` → `led3` (address 0x1000_0230)

## Compilation

The project compiles without errors:
```bash
iverilog -g2005-sv -o simv sim/tb_top.v src/*.v
```

## Notes

- All seg7 operations are simulation-only (force/release)
- Clock synchronization is handled automatically
- Segment patterns are 8-bit values (only lower byte used)
- Multi-digit display shows rightmost 4 decimal digits
