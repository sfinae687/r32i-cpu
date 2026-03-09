`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/04 08:44:39
// Design Name: 
// Module Name: reg_file
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


module reg_file #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    
    input  wire                   we,
    input  wire [ADDR_WIDTH-1:0]  w_addr,
    input  wire [DATA_WIDTH-1:0]  w_data,
    
    input  wire [ADDR_WIDTH-1:0]  r_addr_a,
    output wire [DATA_WIDTH-1:0]  r_data_a,
    
    input  wire [ADDR_WIDTH-1:0]  r_addr_b,
    output wire [DATA_WIDTH-1:0]  r_data_b
);

    reg [DATA_WIDTH-1:0] regs [0:(1<<ADDR_WIDTH)-1];
    integer i;

    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            regs[i] = {DATA_WIDTH{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (we && (w_addr != {ADDR_WIDTH{1'b0}})) begin
            regs[w_addr] <= w_data;
        end
    end

    assign r_data_a = (r_addr_a == {ADDR_WIDTH{1'b0}}) ? {DATA_WIDTH{1'b0}} : regs[r_addr_a];
    assign r_data_b = (r_addr_b == {ADDR_WIDTH{1'b0}}) ? {DATA_WIDTH{1'b0}} : regs[r_addr_b];
    
endmodule
