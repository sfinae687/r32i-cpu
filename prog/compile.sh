#!/bin/bash

################################################################################
# compile.sh - Build RV32I assembly programs to hex format for CPU simulation
#
# Usage:
#   ./compile.sh <source.s> [output_name]
#
# Dependencies:
#   - riscv32-unknown-elf-gcc (RISC-V GNU toolchain)
#   - riscv32-unknown-elf-objcopy
#   - riscv32-unknown-elf-objdump (optional, for disassembly)
#
# Outputs:
#   - <name>.elf       : ELF executable
#   - <name>.bin       : Raw binary
#   - <name>.hex       : Verilog hex format (for $readmemh)
#   - <name>.dump      : Disassembly listing
################################################################################

set -e  # Exit on error

# Check if source file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <source.s> [output_name]"
    exit 1
fi

SOURCE_FILE="$1"
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file '$SOURCE_FILE' not found"
    exit 1
fi

# Determine output name
if [ $# -ge 2 ]; then
    OUTPUT_NAME="$2"
else
    OUTPUT_NAME=$(basename "$SOURCE_FILE" .s)
fi

# Toolchain prefix - try multiple options
if command -v riscv32-unknown-elf-gcc &> /dev/null; then
    PREFIX="riscv32-unknown-elf-"
elif command -v riscv64-unknown-elf-gcc &> /dev/null; then
    PREFIX="riscv64-unknown-elf-"
elif command -v riscv64-linux-gnu-gcc &> /dev/null; then
    PREFIX="riscv64-linux-gnu-"
else
    echo "Error: No RISC-V toolchain found!"
    echo "Please install one of: riscv32-unknown-elf-gcc, riscv64-unknown-elf-gcc, or riscv64-linux-gnu-gcc"
    exit 1
fi

echo "Using toolchain: ${PREFIX}gcc"

# Compiler flags
ARCH_FLAGS="-march=rv32i -mabi=ilp32"
COMMON_FLAGS="-nostdlib -nostartfiles -ffreestanding -static -fno-pic"
LINKER_SCRIPT="linker.ld"

# Check if linker script exists
if [ ! -f "$LINKER_SCRIPT" ]; then
    echo "Error: Linker script '$LINKER_SCRIPT' not found"
    exit 1
fi

echo "========================================="
echo "Compiling: $SOURCE_FILE"
echo "Output:    $OUTPUT_NAME"
echo "========================================="

# Step 1: Assemble and link to ELF
echo "Step 1: Assembling and linking..."
${PREFIX}gcc $ARCH_FLAGS $COMMON_FLAGS -T "$LINKER_SCRIPT" -o "${OUTPUT_NAME}.elf" "$SOURCE_FILE"

# Step 2: Create binary file
echo "Step 2: Creating binary..."
${PREFIX}objcopy -O binary "${OUTPUT_NAME}.elf" "${OUTPUT_NAME}.bin"

# Step 3: Convert binary to Verilog hex format
echo "Step 3: Creating Verilog hex file..."
# objcopy's verilog format doesn't work well with $readmemh for 32-bit words
# Use hexdump to create proper format: one 32-bit word per line in little-endian
hexdump -v -e '1/4 "%08x\n"' "${OUTPUT_NAME}.bin" > "${OUTPUT_NAME}.hex"

# Step 4: Generate disassembly (optional but useful for debugging)
echo "Step 4: Generating disassembly..."
${PREFIX}objdump -d -M numeric "${OUTPUT_NAME}.elf" > "${OUTPUT_NAME}.dump"

# Show file sizes
echo ""
echo "========================================="
echo "Build successful!"
echo "========================================="
ls -lh "${OUTPUT_NAME}.elf" "${OUTPUT_NAME}.bin" "${OUTPUT_NAME}.hex" "${OUTPUT_NAME}.dump"

# Display first few instructions
echo ""
echo "First 10 instructions:"
head -n 20 "${OUTPUT_NAME}.dump" | grep "^[[:space:]]*[0-9a-f]"

echo ""
echo "Hex file ready for simulation: ${OUTPUT_NAME}.hex"
