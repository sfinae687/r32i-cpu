`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/06 08:55:15
// Design Name: 
// Module Name: test_reg_file
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


`timescale 1ns / 1ps

module tb_reg_file();

    // 参数定义
    parameter ADDR_WIDTH = 5;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10;

    // 信号声明
    reg                    clk;
    reg                    we;
    reg  [ADDR_WIDTH-1:0]  w_addr;
    reg  [DATA_WIDTH-1:0]  w_data;
    reg  [ADDR_WIDTH-1:0]  r_addr_a;
    wire [DATA_WIDTH-1:0]  r_data_a;
    reg  [ADDR_WIDTH-1:0]  r_addr_b;
    wire [DATA_WIDTH-1:0]  r_data_b;

    // 例化被测设计 (DUT)
    reg_file #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .we(we),
        .w_addr(w_addr),
        .w_data(w_data),
        .r_addr_a(r_addr_a),
        .r_data_a(r_data_a),
        .r_addr_b(r_addr_b),
        .r_data_b(r_data_b)
    );

    // 时钟产生
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // 测试逻辑
    initial begin
        // 1. 初始化
        we = 0;
        w_addr = 0;
        w_data = 0;
        r_addr_a = 0;
        r_addr_b = 0;
        
        #(CLK_PERIOD * 2);

        // 2. 测试：向 x1 写入数据并读取
        $display("Test 1: Writing 0xABCD1234 to x1...");
        @(negedge clk);
        we = 1; w_addr = 5'd1; w_data = 32'hABCD1234;
        @(negedge clk);
        we = 0; r_addr_a = 5'd1;
        #(CLK_PERIOD);
        if (r_data_a === 32'hABCD1234) 
            $display("Result: Success! x1 = %h", r_data_a);
        else 
            $display("Result: Fail! x1 = %h", r_data_a);

        // 3. 测试：向 x0 写入数据（x0 应该保持为 0）
        $display("Test 2: Attempting to write 0xFFFFFFFF to x0...");
        @(negedge clk);
        we = 1; w_addr = 5'd0; w_data = 32'hFFFFFFFF;
        @(negedge clk);
        we = 0; r_addr_a = 5'd0;
        #(CLK_PERIOD);
        if (r_data_a === 32'h0) 
            $display("Result: Success! x0 remained 0.");
        else 
            $display("Result: Fail! x0 changed to %h", r_data_a);

        // 4. 测试：双端口同时读取不同寄存器
        $display("Test 3: Dual port read (x2 and x3)...");
        @(negedge clk);
        we = 1; w_addr = 5'd2; w_data = 32'h11112222;
        @(negedge clk);
        we = 1; w_addr = 5'd3; w_data = 32'h33334444;
        @(negedge clk);
        we = 0; r_addr_a = 5'd2; r_addr_b = 5'd3;
        #(CLK_PERIOD);
        $display("Result: Port A (x2) = %h, Port B (x3) = %h", r_data_a, r_data_b);

        // 5. 结束仿真
        #(CLK_PERIOD * 5);
        $display("Simulation Finished.");
        $finish;
    end

endmodule