`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/04 08:44:39
// Design Name: 
// Module Name: alu
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


module alu (
    input  [31:0] a,           // 输入数据 A
    input  [31:0] b,           // 输入数据 B
    input  [3:0]  alu_control, // ALU 控制信号
    output reg [31:0] res,     // 运算结果
    output        zero,        // 零标志位 (结果为0时为1)
    output        negative,    // 负标志位 (结果为负时为1)
    output        overflow,    // 溢出标志位 (有符号算术溢出时为1)
    output        carry        // 进位标志位 (无符号加法产生进位时为1)
);

    // 内部信号用于计算进位和溢出
    wire [32:0] add_result;    // 33位用于检测进位
    wire [32:0] sub_result;    // 33位用于检测借位
    
    assign add_result = {1'b0, a} + {1'b0, b};
    assign sub_result = {1'b0, a} - {1'b0, b};

    // 标志位输出逻辑
    assign zero = (res == 32'b0);                          // 零标志：结果为0
    assign negative = res[31];                             // 负标志：结果最高位为1（有符号）
    
    // 溢出标志：仅对ADD和SUB有效
    // ADD溢出：两个同号数相加，结果符号相反
    // SUB溢出：两个异号数相减，结果符号不符预期
    assign overflow = (alu_control == 4'b0010) ?
                      ((a[31] == b[31]) && (res[31] != a[31])) :  // ADD: 同号数相加结果符号相反
                      (alu_control == 4'b0110) ?
                      ((a[31] != b[31]) && (res[31] != a[31])) :  // SUB: 异号数相减结果符号不符
                      1'b0;
    
    // 进位标志：ADD时检测33位结果的最高位
    assign carry = (alu_control == 4'b0010) ? add_result[32] :  // ADD的进位
                   (alu_control == 4'b0110) ? sub_result[32] :  // SUB的借位
                   1'b0;

    always @(*) begin
        case (alu_control)
            4'b0000: res = a & b;                         // AND
            4'b0001: res = a | b;                         // OR
            4'b0010: res = a + b;                         // ADD
            4'b0110: res = a - b;                         // SUB
            4'b0011: res = a ^ b;                         // XOR
            4'b0100: res = a << b[4:0];                   // SLL (逻辑左移)
            4'b0101: res = a >> b[4:0];                   // SRL (逻辑右移)
            4'b1000: res = $signed(a) >>> b[4:0];         // SRA (算术右移)
            4'b0111: res = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT (有符号比较)
            4'b1001: res = (a < b) ? 32'd1 : 32'd0;       // SLTU (无符号比较)
            default: res = 32'b0;
        endcase
    end

endmodule