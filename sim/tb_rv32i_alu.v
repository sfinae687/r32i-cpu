`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/06
// Design Name: 
// Module Name: tb_rv32i_alu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for RV32I CPU with basic arithmetic instructions
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_rv32i_alu;

    // ============== Testbench Signals ==============
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    
    // Reference to internal CPU signals for monitoring
    wire [31:0] pc;
    wire [31:0] imem_rdata;
    wire [4:0] rd;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [6:0] opcode;
    wire [31:0] alu_result;
    wire reg_wr;
    wire [31:0] reg_wr_data;
    wire [31:0] rs1_data, rs2_data;
    
    // Calculate expected ROM address from PC
    wire [9:0] expected_rom_addr = pc[11:2];
    
    // Assign monitoring wires
    assign pc = dut.cpu_inst.pc;
    assign imem_rdata = dut.cpu_inst.imem_rdata;
    assign opcode = imem_rdata[6:0];
    assign rd = imem_rdata[11:7];
    assign rs1 = imem_rdata[19:15];
    assign rs2 = imem_rdata[24:20];
    assign funct3 = imem_rdata[14:12];
    assign funct7 = imem_rdata[31:25];
    assign alu_result = dut.cpu_inst.alu_result;
    assign reg_wr = dut.cpu_inst.reg_wr;
    assign reg_wr_data = dut.cpu_inst.reg_wr_data;
    assign rs1_data = dut.cpu_inst.rs1_data;
    assign rs2_data = dut.cpu_inst.rs2_data;
    
    // ============== Test Data ==============
    integer cycle_count = 0;
    integer error_count = 0;
    integer i;

    task load_default_alu_program;
        begin
            dut.imem_inst.clear_to_nop();

            dut.imem_inst.write_instr(10'd0, 32'h00500093);   // ADDI x1, x0, 5
            dut.imem_inst.write_instr(10'd1, 32'h00300113);   // ADDI x2, x0, 3
            dut.imem_inst.write_instr(10'd2, 32'h002081B3);   // ADD  x3, x1, x2
            dut.imem_inst.write_instr(10'd3, 32'h40218233);   // SUB  x4, x3, x2
            dut.imem_inst.write_instr(10'd4, 32'h0021F2B3);   // AND  x5, x3, x2
            dut.imem_inst.write_instr(10'd5, 32'h0021E333);   // OR   x6, x3, x2
            dut.imem_inst.write_instr(10'd6, 32'h0021C3B3);   // XOR  x7, x3, x2
            dut.imem_inst.write_instr(10'd7, 32'h0071F413);   // ANDI x8, x3, 7
            dut.imem_inst.write_instr(10'd8, 32'h00F1E493);   // ORI  x9, x3, 15
            dut.imem_inst.write_instr(10'd9, 32'h0031C513);   // XORI x10, x3, 3
            dut.imem_inst.write_instr(10'd10, 32'h002095B3);  // SLL  x11, x1, x2
            dut.imem_inst.write_instr(10'd11, 32'h0021D633);  // SRL  x12, x3, x2
            dut.imem_inst.write_instr(10'd12, 32'h4021D6B3);  // SRA  x13, x3, x2
            dut.imem_inst.write_instr(10'd13, 32'h00209713);  // SLLI x14, x1, 2
            dut.imem_inst.write_instr(10'd14, 32'h0011D793);  // SRLI x15, x3, 1
            dut.imem_inst.write_instr(10'd15, 32'h4011D813);  // SRAI x16, x3, 1
            dut.imem_inst.write_instr(10'd16, 32'h0020A8B3);  // SLT  x17, x1, x2
            dut.imem_inst.write_instr(10'd17, 32'h00A1A913);  // SLTI x18, x3, 10
            dut.imem_inst.write_instr(10'd18, 32'h0020B9B3);  // SLTU x19, x1, x2
            dut.imem_inst.write_instr(10'd19, 32'h00A1BA13);  // SLTIU x20, x3, 10
        end
    endtask
    
    // ============== DUT Instantiation ==============
    top_circuit dut(
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // ============== Clock Generation ==============
    // Generate 10ns clock period (100MHz)
    always begin
        #5;
        clk = ~clk;
    end
    
    // ============== Instruction Decode Helper ==============
    function [63:0] decode_instruction;
        input [31:0] instr;
        begin
            case (instr[6:0])
                7'b0010011: // I-type
                    case (instr[14:12])
                        3'b000: decode_instruction = "ADDI    ";
                        3'b001: decode_instruction = "SLLI    ";
                        3'b010: decode_instruction = "SLTI    ";
                        3'b011: decode_instruction = "SLTIU   ";
                        3'b100: decode_instruction = "XORI    ";
                        3'b101: decode_instruction = "SRLI/A  ";
                        3'b110: decode_instruction = "ORI     ";
                        3'b111: decode_instruction = "ANDI    ";
                        default: decode_instruction = "???     ";
                    endcase
                7'b0110011: // R-type
                    case ({instr[31:25], instr[14:12]})
                        10'b0000000_000: decode_instruction = "ADD     ";
                        10'b0100000_000: decode_instruction = "SUB     ";
                        10'b0000000_001: decode_instruction = "SLL     ";
                        10'b0000000_010: decode_instruction = "SLT     ";
                        10'b0000000_011: decode_instruction = "SLTU    ";
                        10'b0000000_100: decode_instruction = "XOR     ";
                        10'b0000000_101: decode_instruction = "SRL     ";
                        10'b0100000_101: decode_instruction = "SRA     ";
                        10'b0000000_110: decode_instruction = "OR      ";
                        10'b0000000_111: decode_instruction = "AND     ";
                        default: decode_instruction = "???     ";
                    endcase
                default: decode_instruction = "UNKNOWN ";
            endcase
        end
    endfunction
    
    // ============== Main Test Process ==============
    initial begin
        $display("\n========== RV32I CPU Execution Test ==========\n");

        load_default_alu_program();
        
        // ============== Phase 1: Initialize and Reset ==============
        $display("Phase 1: System Reset");
        $display("---------------------");
        rst_n = 1'b0;
        clk = 1'b0;
        #10;
        $display("t=%0t: Reset asserted (rst_n=0)", $time);
        $display("         PC = 0x%08h", pc);
        $display("         imem_rdata = 0x%08h", imem_rdata);
        
        #40;
        $display("t=%0t: Releasing reset (rst_n will go to 1)", $time);
        rst_n = 1'b1;
        
        #5;
        $display("t=%0t: After reset release, before first clock", $time);
        $display("         PC = 0x%08h (should be 0x0)", pc);
        $display("         imem_rdata = 0x%08h", imem_rdata);
        
        // ============== Phase 2: Execute Instructions ==============
        $display("\nPhase 2: Instruction Execution");
        $display("------------------------------");
        $display("Cyl | PC_Value | PC[11:2] | Instruction | Opcode | funct3 | rd | rs1 | rs2 | ALU_Result | RegWr");
        $display("-----|----------|----------|----------|--------|--------|----|----|-----|------------|-----");
        
        cycle_count = 0;
        
        // Sample before first clock edge
        $display("%3d | 0x%06h  | rom[%2d] | 0x%08h | 0x%02h   | %3d    | %2d | %2d | %2d | 0x%08h | %b", 
            cycle_count, pc[11:0], expected_rom_addr, imem_rdata, opcode, funct3, rd, rs1, rs2, alu_result, reg_wr);
        
        // Run 32 more cycles
        repeat(32) begin
            @(posedge clk);
            #1;  // Wait for non-blocking register updates (e.g., PC writeback)
            cycle_count = cycle_count + 1;
            
            $display("%3d | 0x%06h  | rom[%2d] | 0x%08h | 0x%02h   | %3d    | %2d | %2d | %2d | 0x%08h | %b", 
                cycle_count, pc[11:0], expected_rom_addr, imem_rdata, opcode, funct3, rd, rs1, rs2, alu_result, reg_wr);
        end
        
        // ============== Test Phase 3: Register Verification ==============
        $display("\n========== Test Phase 3: Register File State ==========");
        $display("Register | Final Value | Expected Value");
        $display("----------|-------------|-------------------");
        $display("x0       | 0x%08h  | 0x00000000 (always zero)", dut.cpu_inst.regs.regs[0]);
        $display("x1       | 0x%08h  | 0x00000005 (ADDI x1,x0,5)", dut.cpu_inst.regs.regs[1]);
        $display("x2       | 0x%08h  | 0x00000003 (ADDI x2,x0,3)", dut.cpu_inst.regs.regs[2]);
        $display("x3       | 0x%08h  | 0x00000008 (ADD x3,x1,x2=5+3)", dut.cpu_inst.regs.regs[3]);
        $display("x4       | 0x%08h  | 0x00000005 (SUB x4,x3,x2=8-3)", dut.cpu_inst.regs.regs[4]);
        $display("x5       | 0x%08h  | 0x00000000 (AND x5,x3,x2=8&3)", dut.cpu_inst.regs.regs[5]);
        $display("x6       | 0x%08h  | 0x0000000b (OR x6,x3,x2=8|3)", dut.cpu_inst.regs.regs[6]);
        $display("x7       | 0x%08h  | 0x0000000b (XOR x7,x3,x2=8^3)", dut.cpu_inst.regs.regs[7]);
        $display("x8       | 0x%08h  | 0x00000000 (ANDI x8,x3,7=8&7)", dut.cpu_inst.regs.regs[8]);
        
        // ============== Simulation Complete ==============
        $display("\n========== Simulation Complete ==========");
        $display("Total cycles: %d", cycle_count);
        
        #100;
        $stop();
    end

endmodule
