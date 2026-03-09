`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/03 13:01:04
// Design Name: 
// Module Name: basic_test
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


module basic_test;

    reg clk = 1'b0;
    
    always begin
        #10;
        clk <= ! clk;
    end
    
    top_circuit cpu(
        .clk(clk),
        .led0()
    );

endmodule
