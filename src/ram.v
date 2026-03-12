`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/04 10:01:57
// Design Name: 
// Module Name: dram
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

module dram #(
    parameter ADDR_WIDTH = 11,       // 2048个字 (8KB)
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   we,      // 写使能
    input  wire [3:0]             byte_we, // 字节写使能 (用于 SB/SH/SW)
    input  wire [ADDR_WIDTH-1:0]  addr,    // 输入地址（通常是按字对齐的地址）
    input  wire [DATA_WIDTH-1:0]  din,     // 写入数据
    output wire [DATA_WIDTH-1:0]  dout     // 读取数据
);

    // 使用字节寻址的存储阵列 (4个8位内存块，方便实现按字节写入)
    reg [7:0] ram0 [0:(1<<ADDR_WIDTH)-1];
    reg [7:0] ram1 [0:(1<<ADDR_WIDTH)-1];
    reg [7:0] ram2 [0:(1<<ADDR_WIDTH)-1];
    reg [7:0] ram3 [0:(1<<ADDR_WIDTH)-1];

    // 同步写操作 (Synchronous Write)
    always @(posedge clk) begin
        if (we) begin
            if (byte_we[0]) ram0[addr] <= din[7:0];
            if (byte_we[1]) ram1[addr] <= din[15:8];
            if (byte_we[2]) ram2[addr] <= din[23:16];
            if (byte_we[3]) ram3[addr] <= din[31:24];
        end
    end

    // 组合逻辑读操作 (Asynchronous Read - 单周期常用)
    // 这样 ALU 计算出的地址可以在同一个周期直接读出数据给回寄存器
    assign dout = {ram3[addr], ram2[addr], ram1[addr], ram0[addr]};

endmodule