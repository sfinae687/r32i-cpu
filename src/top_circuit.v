`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/03 12:48:51
// Design Name: 
// Module Name: top_circuit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_circuit(
    input clk,
    input rst_n
    );
    
    // ============== Instruction Memory Interface ==============
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    
    // ============== Data Memory Interface ==============
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    
    // ============== CPU Instantiation ==============
    cpu cpu_inst(
        .clk (clk),
        .rst_n (rst_n),
        .imem_addr (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_we (dmem_we),
        .dmem_be (dmem_be)
    );
    
    // ============== Instruction Memory Instantiation ==============
    imem imem_inst(
        .addr (imem_addr[11:2]),  // Convert byte address to word address (10-bit index)
        .dout (imem_rdata)
    );
    
    // ============== Data Memory Instantiation ==============
    dram #(
        .ADDR_WIDTH (10),
        .DATA_WIDTH (32)
    ) dmem_inst(
        .clk (clk),
        .we (dmem_we),
        .byte_we (dmem_be),
        .addr (dmem_addr[11:2]),  // Convert byte address to word address
        .din (dmem_wdata),
        .dout (dmem_rdata)
    );
    
endmodule
