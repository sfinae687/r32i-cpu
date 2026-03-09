`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Comprehensive Testbench for RV32I Control Flow Instructions
// 
// Tests Coverage:
// - Branch (taken):     BEQ, BNE, BLT, BGE, BLTU, BGEU
// - Branch (not taken): BEQ, BLT
// - Forward branches:   All branch instructions
// - Backward branches:  Loop test with BNE
// - JAL:                Forward jump with return address
// - JALR:               Indirect jump with return address
// - LUI:                Load upper immediate
// - AUIPC:              Add upper immediate to PC
//
// Create Date: 2026/03/09 08:39:16
// Last Modified: 2026/03/09
//////////////////////////////////////////////////////////////////////////////////

module tb_control();

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // CPU signals
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    
    // Loop variable
    integer i;
    integer max_wait_cycles;
    
    // Instantiate CPU
    cpu uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be)
    );
    
    // Instruction memory (ROM)
    imem #(
        .ADDR_WIDTH(6),
        .DATA_WIDTH(32)
    ) imem_model (
        .addr(imem_addr[7:2]),
        .dout(imem_rdata)
    );
    
    // Data memory (RAM)
    reg [31:0] dmem [0:63];
    
    // Clock generation: 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Data memory read/write
    always @(posedge clk) begin
        if (dmem_we) begin
            // Write to data memory with byte enable
            if (dmem_be[0]) dmem[dmem_addr][7:0]   <= dmem_wdata[7:0];
            if (dmem_be[1]) dmem[dmem_addr][15:8]  <= dmem_wdata[15:8];
            if (dmem_be[2]) dmem[dmem_addr][23:16] <= dmem_wdata[23:16];
            if (dmem_be[3]) dmem[dmem_addr][31:24] <= dmem_wdata[31:24];
        end
    end
    
    always @(*) begin
        dmem_rdata = dmem[dmem_addr];
    end
    
    // Helper function to create R-type instruction
    function [31:0] r_type;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            r_type = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction
    
    // Helper function to create I-type instruction
    function [31:0] i_type;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            i_type = {imm, rs1, funct3, rd, opcode};
        end
    endfunction
    
    // Helper function to create S-type instruction
    function [31:0] s_type;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            s_type = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
        end
    endfunction
    
    // Helper function to create B-type instruction
    function [31:0] b_type;
        input [12:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            b_type = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
        end
    endfunction
    
    // Helper function to create U-type instruction
    function [31:0] u_type;
        input [19:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            u_type = {imm, rd, opcode};
        end
    endfunction
    
    // Helper function to create J-type instruction
    function [31:0] j_type;
        input [20:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            j_type = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
        end
    endfunction
    
    // Test program
    initial begin
        // ========== Comprehensive Control Flow Test Program ==========
        imem_model.clear_to_nop();
        
        // === Setup: Initialize test registers ===
        imem_model.write_instr(6'd0,  i_type(12'd10, 5'd0, 3'b000, 5'd1, 7'b0010011));   // x1 = 10
        imem_model.write_instr(6'd1,  i_type(12'd20, 5'd0, 3'b000, 5'd2, 7'b0010011));   // x2 = 20
        imem_model.write_instr(6'd2,  i_type(-12'd5, 5'd0, 3'b000, 5'd3, 7'b0010011));   // x3 = -5
        imem_model.write_instr(6'd3,  i_type(12'd10, 5'd0, 3'b000, 5'd4, 7'b0010011));   // x4 = 10
        
        // === Test 1: BEQ (taken) ===
        imem_model.write_instr(6'd4,  b_type(13'd8, 5'd4, 5'd1, 3'b000, 7'b1100011));    // BEQ x1, x4, +8
        imem_model.write_instr(6'd5,  i_type(12'd99, 5'd0, 3'b000, 5'd5, 7'b0010011));   // x5 = 99 (skipped)
        imem_model.write_instr(6'd6,  i_type(12'd1, 5'd0, 3'b000, 5'd5, 7'b0010011));    // x5 = 1  (executed)
        
        // === Test 2: BEQ (not taken) ===
        imem_model.write_instr(6'd7,  b_type(13'd8, 5'd2, 5'd1, 3'b000, 7'b1100011));    // BEQ x1, x2, +8
        imem_model.write_instr(6'd8,  i_type(12'd11, 5'd0, 3'b000, 5'd17, 7'b0010011));  // x17 = 11 (executed)
        
        // === Test 3: BNE (taken) ===
        imem_model.write_instr(6'd9,  b_type(13'd8, 5'd2, 5'd1, 3'b001, 7'b1100011));    // BNE x1, x2, +8
        imem_model.write_instr(6'd10, i_type(12'd99, 5'd0, 3'b000, 5'd6, 7'b0010011));   // x6 = 99 (skipped)
        imem_model.write_instr(6'd11, i_type(12'd2, 5'd0, 3'b000, 5'd6, 7'b0010011));    // x6 = 2  (executed)
        
        // === Test 4: BLT (taken, signed) ===
        imem_model.write_instr(6'd12, b_type(13'd8, 5'd1, 5'd3, 3'b100, 7'b1100011));    // BLT x3, x1, +8 (-5 < 10)
        imem_model.write_instr(6'd13, i_type(12'd99, 5'd0, 3'b000, 5'd7, 7'b0010011));   // x7 = 99 (skipped)
        imem_model.write_instr(6'd14, i_type(12'd3, 5'd0, 3'b000, 5'd7, 7'b0010011));    // x7 = 3  (executed)
        
        // === Test 5: BLT (not taken) ===
        imem_model.write_instr(6'd15, b_type(13'd8, 5'd1, 5'd2, 3'b100, 7'b1100011));    // BLT x2, x1, +8 (20 < 10? no)
        imem_model.write_instr(6'd16, i_type(12'd12, 5'd0, 3'b000, 5'd18, 7'b0010011));  // x18 = 12 (executed)
        
        // === Test 6: BGE (taken) ===
        imem_model.write_instr(6'd17, b_type(13'd8, 5'd1, 5'd2, 3'b101, 7'b1100011));    // BGE x2, x1, +8 (20 >= 10)
        imem_model.write_instr(6'd18, i_type(12'd99, 5'd0, 3'b000, 5'd8, 7'b0010011));   // x8 = 99 (skipped)
        imem_model.write_instr(6'd19, i_type(12'd4, 5'd0, 3'b000, 5'd8, 7'b0010011));    // x8 = 4  (executed)
        
        // === Test 7: BLTU (taken, unsigned) ===
        // x1=10, x3=-5(unsigned=4294967291), 10 < 4294967291
        imem_model.write_instr(6'd20, b_type(13'd8, 5'd3, 5'd1, 3'b110, 7'b1100011));    // BLTU x1, x3, +8
        imem_model.write_instr(6'd21, i_type(12'd99, 5'd0, 3'b000, 5'd9, 7'b0010011));   // x9 = 99 (skipped)
        imem_model.write_instr(6'd22, i_type(12'd5, 5'd0, 3'b000, 5'd9, 7'b0010011));    // x9 = 5  (executed)
        
        // === Test 8: BGEU (taken) ===
        imem_model.write_instr(6'd23, b_type(13'd8, 5'd1, 5'd2, 3'b111, 7'b1100011));    // BGEU x2, x1, +8 (20 >= 10)
        imem_model.write_instr(6'd24, i_type(12'd99, 5'd0, 3'b000, 5'd10, 7'b0010011));  // x10 = 99 (skipped)
        imem_model.write_instr(6'd25, i_type(12'd6, 5'd0, 3'b000, 5'd10, 7'b0010011));   // x10 = 6  (executed)
        
        // === Test 9: JAL (forward jump) ===
        imem_model.write_instr(6'd26, j_type(21'd12, 5'd11, 7'b1101111));                // JAL x11, +12; PC=104, ret=108
        imem_model.write_instr(6'd27, i_type(12'd99, 5'd0, 3'b000, 5'd12, 7'b0010011));  // x12 = 99 (skipped)
        imem_model.write_instr(6'd28, i_type(12'd99, 5'd0, 3'b000, 5'd13, 7'b0010011));  // x13 = 99 (skipped)
        imem_model.write_instr(6'd29, i_type(12'd7, 5'd0, 3'b000, 5'd12, 7'b0010011));   // x12 = 7  (executed)
        
        // === Test 10: JALR (indirect jump) ===
        imem_model.write_instr(6'd30, i_type(12'd152, 5'd0, 3'b000, 5'd14, 7'b0010011)); // x14 = 152 (target PC)
        imem_model.write_instr(6'd31, i_type(12'd0, 5'd14, 3'b000, 5'd15, 7'b1100111));  // JALR x15, x14, 0; ret=128
        imem_model.write_instr(6'd32, i_type(12'd99, 5'd0, 3'b000, 5'd16, 7'b0010011));  // x16 = 99 (skipped)
        imem_model.write_instr(6'd33, i_type(12'd99, 5'd0, 3'b000, 5'd21, 7'b0010011));  // x21 = 99 (skipped)
        // ... more skipped instructions ...
        imem_model.write_instr(6'd38, i_type(12'd8, 5'd0, 3'b000, 5'd16, 7'b0010011));   // x16 = 8  (PC=152, executed)
        
        // === Test 11: LUI ===
        imem_model.write_instr(6'd39, u_type(20'h12345, 5'd22, 7'b0110111));             // LUI x22, 0x12345
        
        // === Test 12: AUIPC ===
        imem_model.write_instr(6'd40, u_type(20'h100, 5'd23, 7'b0010111));               // AUIPC x23, 0x100; PC=160
        
        // === Test 13: Backward branch (simple loop) ===
        // Loop: x19 counts from 0 to 2 (exits when x19==3)
        imem_model.write_instr(6'd41, i_type(12'd0, 5'd0, 3'b000, 5'd19, 7'b0010011));   // x19 = 0
        imem_model.write_instr(6'd42, i_type(12'd3, 5'd0, 3'b000, 5'd20, 7'b0010011));   // x20 = 3 (limit)
        // Loop start (PC=172):
        imem_model.write_instr(6'd43, i_type(12'd1, 5'd19, 3'b000, 5'd19, 7'b0010011));  // x19 = x19 + 1
        imem_model.write_instr(6'd44, b_type(-13'd8, 5'd20, 5'd19, 3'b001, 7'b1100011)); // BNE x19,x20,-8 -> back to 172
        // Loop exit (PC=180):
        imem_model.write_instr(6'd45, i_type(12'd100, 5'd0, 3'b000, 5'd24, 7'b0010011)); // x24 = 100 (sentinel)
        
        // End of program
        imem_model.write_instr(6'd46, i_type(12'd0, 5'd0, 3'b000, 5'd0, 7'b0010011));    // NOP
    end
    
    // Test sequence
    initial begin
        $display("========================================");
        $display("RV32I Control Flow Instructions Test");
        $display("========================================");
        
        // Initialize
        rst_n = 0;
        dmem_rdata = 0;
        
        // Initialize data memory
        for (i = 0; i < 64; i = i + 1) begin
            dmem[i] = 32'h0;
        end
        
        // Reset pulse
        #20;
        rst_n = 1;

        // Wait until program reaches completion sentinel (x24 == 100).
        // Use case-inequality (!==) so unknown X values keep waiting.
        max_wait_cycles = 200;
        while ((uut.regs.regs[24] !== 32'd100) && (max_wait_cycles > 0)) begin
            @(posedge clk);
            max_wait_cycles = max_wait_cycles - 1;
        end

        if (max_wait_cycles == 0) begin
            $display("\n✗ TIMEOUT: program did not reach completion sentinel x24=100");
            $finish;
        end

        // One extra cycle to settle final writeback before checks
        @(posedge clk);
        
        // Check results
        $display("\n=== Register Values After Execution ===");
        $display("x1  (init: 10)     = %d", uut.regs.regs[1]);
        $display("x2  (init: 20)     = %d", uut.regs.regs[2]);
        $display("x3  (init: -5)     = %d (signed: %d)", uut.regs.regs[3], $signed(uut.regs.regs[3]));
        $display("x4  (init: 10)     = %d", uut.regs.regs[4]);
        $display("x5  (expect: 1)    = %d [BEQ taken]", uut.regs.regs[5]);
        $display("x6  (expect: 2)    = %d [BNE taken]", uut.regs.regs[6]);
        $display("x7  (expect: 3)    = %d [BLT taken]", uut.regs.regs[7]);
        $display("x8  (expect: 4)    = %d [BGE taken]", uut.regs.regs[8]);
        $display("x9  (expect: 5)    = %d [BLTU taken]", uut.regs.regs[9]);
        $display("x10 (expect: 6)    = %d [BGEU taken]", uut.regs.regs[10]);
        $display("x11 (expect: 108)  = %d [JAL return PC]", uut.regs.regs[11]);
        $display("x12 (expect: 7)    = %d [JAL target]", uut.regs.regs[12]);
        $display("x14 (expect: 152)  = %d [JALR base]", uut.regs.regs[14]);
        $display("x15 (expect: 128)  = %d [JALR return PC]", uut.regs.regs[15]);
        $display("x16 (expect: 8)    = %d [JALR target]", uut.regs.regs[16]);
        $display("x17 (expect: 11)   = %d [BEQ not taken]", uut.regs.regs[17]);
        $display("x18 (expect: 12)   = %d [BLT not taken]", uut.regs.regs[18]);
        $display("x19 (expect: 3)    = %d [Loop counter]", uut.regs.regs[19]);
        $display("x20 (expect: 3)    = %d [Loop limit]", uut.regs.regs[20]);
        $display("x22 (expect: 0x12345000) = 0x%h [LUI]", uut.regs.regs[22]);
        $display("x23 (expect: 0x001000a0) = 0x%h [AUIPC: PC=160 + 0x00100000]", uut.regs.regs[23]);
        $display("x24 (expect: 100)  = %d [Loop exit sentinel]", uut.regs.regs[24]);
        
        // Verification
        $display("\n=== Test Results ===");
        
        // Branch tests (taken)
        if (uut.regs.regs[5] == 1)  $display("✓ BEQ (taken) PASSED");
        else $display("✗ BEQ (taken) FAILED: got %d", uut.regs.regs[5]);
        
        if (uut.regs.regs[6] == 2)  $display("✓ BNE (taken) PASSED");
        else $display("✗ BNE (taken) FAILED: got %d", uut.regs.regs[6]);
        
        if (uut.regs.regs[7] == 3)  $display("✓ BLT (taken) PASSED");
        else $display("✗ BLT (taken) FAILED: got %d", uut.regs.regs[7]);
        
        if (uut.regs.regs[8] == 4)  $display("✓ BGE (taken) PASSED");
        else $display("✗ BGE (taken) FAILED: got %d", uut.regs.regs[8]);
        
        if (uut.regs.regs[9] == 5)  $display("✓ BLTU (taken) PASSED");
        else $display("✗ BLTU (taken) FAILED: got %d", uut.regs.regs[9]);
        
        if (uut.regs.regs[10] == 6) $display("✓ BGEU (taken) PASSED");
        else $display("✗ BGEU (taken) FAILED: got %d", uut.regs.regs[10]);
        
        // Branch tests (not taken)
        if (uut.regs.regs[17] == 11) $display("✓ BEQ (not taken) PASSED");
        else $display("✗ BEQ (not taken) FAILED: got %d", uut.regs.regs[17]);
        
        if (uut.regs.regs[18] == 12) $display("✓ BLT (not taken) PASSED");
        else $display("✗ BLT (not taken) FAILED: got %d", uut.regs.regs[18]);
        
        // Jump tests
        if (uut.regs.regs[12] == 7) $display("✓ JAL (target) PASSED");
        else $display("✗ JAL (target) FAILED: got %d", uut.regs.regs[12]);
        
        if (uut.regs.regs[11] == 108) $display("✓ JAL (return addr) PASSED");
        else $display("✗ JAL (return addr) FAILED: got %d, expected 108", uut.regs.regs[11]);
        
        if (uut.regs.regs[16] == 8) $display("✓ JALR (target) PASSED");
        else $display("✗ JALR (target) FAILED: got %d", uut.regs.regs[16]);
        
        if (uut.regs.regs[15] == 128) $display("✓ JALR (return addr) PASSED");
        else $display("✗ JALR (return addr) FAILED: got %d, expected 128", uut.regs.regs[15]);
        
        // LUI and AUIPC
        if (uut.regs.regs[22] == 32'h12345000) $display("✓ LUI PASSED");
        else $display("✗ LUI FAILED: got 0x%h, expected 0x12345000", uut.regs.regs[22]);
        
        if (uut.regs.regs[23] == 32'h001000A0) $display("✓ AUIPC PASSED");
        else $display("✗ AUIPC FAILED: got 0x%h, expected 0x001000A0", uut.regs.regs[23]);
        
        // Backward branch (loop)
        if (uut.regs.regs[19] == 3) $display("✓ Backward branch (loop counter) PASSED");
        else $display("✗ Backward branch (loop counter) FAILED: got %d", uut.regs.regs[19]);
        
        if (uut.regs.regs[24] == 100) $display("✓ Loop exit verification PASSED");
        else $display("✗ Loop exit verification FAILED: got %d", uut.regs.regs[24]);
        
        // Summary
        $display("\n=== Test Coverage Summary ===");
        $display("✓ Branch instructions (taken): BEQ, BNE, BLT, BGE, BLTU, BGEU");
        $display("✓ Branch instructions (not taken): BEQ, BLT");
        $display("✓ Forward branches");
        $display("✓ Backward branches (loops)");
        $display("✓ JAL with return address verification");
        $display("✓ JALR with return address verification");
        $display("✓ LUI (Load Upper Immediate)");
        $display("✓ AUIPC (Add Upper Immediate to PC)");
        
        $display("\n========================================");
        $display("Comprehensive test completed!");
        $display("========================================");
        $finish;
    end
    
    // Optional: Waveform dump
    initial begin
        $dumpfile("tb_control.vcd");
        $dumpvars(0, tb_control);
    end

endmodule
