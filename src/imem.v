`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/06
// Design Name: 
// Module Name: imem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: RV32I Instruction Memory Module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module imem #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32,
    parameter FILE_INIT = ""          // If specified, load instructions from this binary file
)(
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] dout
);

    localparam [31:0] RV32I_NOP = 32'h00000013;

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    integer i;

    // Initialize memory: either from file or with NOPs
    initial begin
        // First, fill with NOPs
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = RV32I_NOP;
        end
        
        // Then, load from file if FILE_INIT is specified
        if (FILE_INIT != "") begin
            $readmemh(FILE_INIT, mem);
        end
    end

    // Testbench helper: clear whole IMEM to NOP.
    task clear_to_nop;
        integer idx;
        begin
            for (idx = 0; idx < (1<<ADDR_WIDTH); idx = idx + 1) begin
                mem[idx] = RV32I_NOP;
            end
        end
    endtask

    // Testbench helper: write one instruction word by word index.
    task write_instr;
        input [ADDR_WIDTH-1:0] word_addr;
        input [DATA_WIDTH-1:0] instr;
        begin
            mem[word_addr] = instr;
        end
    endtask

    // Asynchronous read for single-cycle CPU fetch.
    assign dout = mem[addr];

endmodule
