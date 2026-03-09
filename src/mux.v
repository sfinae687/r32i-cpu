`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/04 09:32:20
// Design Name: 
// Module Name: mux
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


module mux #(
    parameter DATA_WIDTH = 8,       // 每个输入通道的数据位宽
    parameter SELECT_WIDTH = 2,     // 选择信号位宽
    parameter CHANNELS = 2**SELECT_WIDTH // 自动计算通道数 (2^SEL)
) (
    input  wire [CHANNELS*DATA_WIDTH-1:0] data_in, // 展平后的输入总线
    input  wire [SELECT_WIDTH-1:0]        sel,     // 选择信号
    output reg  [DATA_WIDTH-1:0]          data_out // 输出数据
);

    always @(*) begin
        data_out = data_in[sel * DATA_WIDTH +: DATA_WIDTH];
    end

endmodule