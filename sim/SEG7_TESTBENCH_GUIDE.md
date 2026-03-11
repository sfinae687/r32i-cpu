# 7-Segment Display Support in tb_top.v

## Overview

The testbench now provides comprehensive support for testing 7-segment LED displays controlled by the `seg7_cont` module. The hardware uses 4 independent 7-segment display controllers (dev0-dev3), each mapped to the LED memory-mapped I/O region.

## Hardware Mapping

```
Device  | Address         | Description
--------|-----------------|-------------------
seg7_0  | 0x1000_0200     | 7-segment controller 0
seg7_1  | 0x1000_0210     | 7-segment controller 1
seg7_2  | 0x1000_0220     | 7-segment controller 2
seg7_3  | 0x1000_0230     | 7-segment controller 3
```

Each controller has 3 register offsets:
- `0x00`: DATA register (read/write) — direct value write
- `0x04`: SET register (write) — set bits (OR with current)
- `0x08`: CLR register (write) — clear bits (AND-NOT with current)

## 7-Segment Encoding

The display segments are encoded in bits 7:0:

```
     A (bit 0)
   F (5) B (1)
     G (bit 6)
   E (4) C (2)
     D (bit 3)
   . (bit 7) = decimal point
```

Bit mapping:
- Bit 0 (0x01): Segment A
- Bit 1 (0x02): Segment B
- Bit 2 (0x04): Segment C
- Bit 3 (0x08): Segment D
- Bit 4 (0x10): Segment E
- Bit 5 (0x20): Segment F
- Bit 6 (0x40): Segment G
- Bit 7 (0x80): Decimal Point (DP)

### Common Patterns

Hexadecimal digit encoding is automatically handled by the `seg7_encode_hex()` function:

```
0: 0x3F (0011_1111) = A,B,C,D,E,F
1: 0x06 (0000_0110) = B,C
2: 0x5B (0101_1011) = A,B,G,E,D
3: 0x4F (0100_1111) = A,B,C,D,G
4: 0x66 (0110_0110) = F,B,G,C
5: 0x6D (0110_1101) = A,F,G,C,D
6: 0x7D (0111_1101) = A,F,G,E,C,D
7: 0x07 (0000_0111) = A,B,C
8: 0x7F (0111_1111) = all segments
9: 0x6F (0110_1111) = A,B,C,D,F,G
A: 0x77 (0111_0111) = A,B,C,E,F,G
B: 0x7C (0111_1100) = C,D,E,F,G
C: 0x39 (0011_1001) = A,D,E,F
D: 0x5E (0101_1110) = B,C,D,E,G
E: 0x79 (0111_1001) = A,D,E,F,G
F: 0x71 (0111_0001) = A,E,F,G
```

## Available Tasks

### Basic I/O

#### `seg7_read_raw(dev, value)`
Read the current 7-segment pattern from a controller.

**Parameters:**
- `dev`: Device index (0-3)
- `value`: Output variable to store the read pattern

**Example:**
```verilog
seg7_read_raw(0, pattern);
$display("Current pattern: 0x%02h", pattern[7:0]);
```

#### `seg7_write_raw(dev, value)`
Write a raw 7-segment pattern directly to a controller.

**Parameters:**
- `dev`: Device index (0-3)
- `value`: 32-bit value (only lower 8 bits used for segment pattern)

**Example:**
```verilog
seg7_write_raw(0, 32'h0000_003F);  // Display "0"
seg7_write_raw(1, 32'h0000_0006);  // Display "1"
```

### High-Level Display Functions

#### `seg7_show_hex(dev, hex_digit)`
Display a hexadecimal digit (0-F) on a 7-segment controller.

**Parameters:**
- `dev`: Device index (0-3)
- `hex_digit`: 4-bit hex value (0x0-0xF)

**Example:**
```verilog
seg7_show_hex(0, 4'h5);    // Display "5"
seg7_show_hex(1, 4'hA);    // Display "A"
```

#### `seg7_show_dec_digit(dev, dec_digit)`
Display a decimal digit (0-9) on a 7-segment controller.

**Parameters:**
- `dev`: Device index (0-3)
- `dec_digit`: 4-bit decimal value (0-9)

**Example:**
```verilog
seg7_show_dec_digit(0, 4'd7);    // Display "7"
seg7_show_dec_digit(2, 4'd3);    // Display "3"
```

#### `seg7_show_u32(value)`
Display a 32-bit unsigned integer across all 4 display controllers.
- dev0 displays ones place
- dev1 displays tens place
- dev2 displays hundreds place
- dev3 displays thousands place

Only the last 4 digits (0-9999) are displayed.

**Parameters:**
- `value`: 32-bit unsigned value to display

**Example:**
```verilog
seg7_show_u32(1234);      // Displays "1234"
seg7_show_u32(42);        // Displays "0042"
seg7_show_u32(999);       // Displays "0999"
```

#### `seg7_wait_pattern(dev, expected_pattern, max_cycles)`
Wait until a 7-segment display shows a specific pattern or timeout.

**Parameters:**
- `dev`: Device index (0-3)
- `expected_pattern`: 32-bit value (only lower 8 bits used)
- `max_cycles`: Maximum clock cycles to wait

**Example:**
```verilog
seg7_wait_pattern(0, 32'h3F, 1000);  // Wait for "0" to appear on dev0
```

#### `seg7_clear_all()`
Clear all 7-segment displays (turn off all segments on all 4 devices).

**Example:**
```verilog
seg7_clear_all();    // All displays off
```

## Script File Commands

When using the script-driven testbench with `+SCRIPT=<file>`, the following commands are available:

### Display Commands

#### `seg7_write <dev> <pattern_hex>`
Write a raw 7-segment pattern.

```
seg7_write 0 3F     # Display "0" on dev0 (hex 0x3F)
seg7_write 1 06     # Display "1" on dev1 (hex 0x06)
```

#### `seg7_show_hex <dev> <hex_digit>`
Display a hexadecimal digit.

```
seg7_show_hex 0 5   # Display hex digit 5 on dev0
seg7_show_hex 1 A   # Display hex digit A on dev1
```

#### `seg7_show_dec <dev> <dec_digit>`
Display a decimal digit.

```
seg7_show_dec 0 7   # Display number 7 on dev0
seg7_show_dec 2 3   # Display number 3 on dev2
```

#### `seg7_show_u32 <value>`
Display a 32-bit value across all 4 displays.

```
seg7_show_u32 1234   # Shows "1234" (dev0=4, dev1=3, dev2=2, dev3=1)
seg7_show_u32 999    # Shows "0999"
```

#### `seg7_clear`
Clear all 7-segment displays.

```
seg7_clear           # Turn off all displays
```

### Synchronization Commands

#### `seg7_wait <dev> <pattern_hex> <max_cycles>`
Wait for a specific pattern to appear on a display.

```
seg7_wait 0 3F 1000     # Wait up to 1000 cycles for pattern 0x3F on dev0
seg7_wait 1 06 5000     # Wait up to 5000 cycles for pattern 0x06 on dev1
```

## Example Usage

### Interactive Testbench

```verilog
initial begin
    tb_reset();
    tb_set_uart_baud_fast();
    
    // Show counting sequence
    seg7_show_dec_digit(0, 0);
    repeat(100) @(posedge clk);
    
    seg7_show_dec_digit(0, 1);
    repeat(100) @(posedge clk);
    
    // Display a multi-digit number
    seg7_show_u32(5678);
    repeat(200) @(posedge clk);
    
    // Wait for CPU to modify display (test from CPU-side)
    seg7_wait_pattern(2, 32'h5B, 50000);  // Wait for "2" on dev2
    
    // Clear all
    seg7_clear_all();
    repeat(100) @(posedge clk);
    
    $finish;
end
```

### Script-Driven Testbench

Content of `demo.script`:
```
wait 100
seg7_clear
wait 50
seg7_show_hex 0 0
wait 100
seg7_show_hex 0 1
wait 100
seg7_show_u32 1234
wait 200
seg7_clear
wait 100
finish
```

Run with:
```bash
vvp simv +PROG=prog/example.hex +SCRIPT=sim/demo.script
```

## Testing Tips

1. **Pattern Verification**: Use `seg7_wait_pattern()` to synchronize testbench operations with CPU-driven display updates.

2. **Decimal Display**: For counting/score displays, use `seg7_show_u32()` which automatically extracts digits (0-9999).

3. **Hex Debugging**: Use `seg7_show_hex()` to display raw values for debugging (0-F).

4. **Raw Access**: Use `seg7_write_raw()` for custom patterns (mixed segments, decorative patterns, etc.).

5. **Timing**: Remember that `seg7_show_*` tasks include @(posedge clk) delays. Plan test timing accordingly.

## Constants in testbench

The following segment constants are defined for custom use:

```verilog
localparam [7:0] SEG7_SEG_A   = 8'h01;
localparam [7:0] SEG7_SEG_B   = 8'h02;
localparam [7:0] SEG7_SEG_C   = 8'h04;
localparam [7:0] SEG7_SEG_D   = 8'h08;
localparam [7:0] SEG7_SEG_E   = 8'h10;
localparam [7:0] SEG7_SEG_F   = 8'h20;
localparam [7:0] SEG7_SEG_G   = 8'h40;
localparam [7:0] SEG7_SEG_DP  = 8'h80;
```

These can be combined with logical OR to create custom patterns:
```verilog
/* Display just the top horizontal segment (A) */
seg7_write_raw(0, SEG7_SEG_A);

/* Display "8" with decimal point */
seg7_write_raw(0, 8'h7F | SEG7_SEG_DP);
```

## Implementation Notes

- The `seg7_write_raw()` task uses Verilog hierarchical force/release to directly modify the internal register of `seg7_ctrl` instances.
- This is a simulation-only feature; the force/release commands are not synthesizable.
- The encoding function `seg7_encode_hex()` is implemented as a Verilog function for maximum efficiency.
- All tasks include proper clock synchronization with @(posedge clk).
