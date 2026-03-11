`timescale 1ns / 1ps

module tb_btn_cont;

    localparam [31:0] BTN_BASE_ADDR = 32'h1000_0120;
    localparam [31:0] REG_DATA_OFF  = 32'h0000_0000;
    localparam [31:0] REG_EDGE_OFF  = 32'h0000_0004;

    reg         clk;
    reg         rst_n;
    reg         cs;
    reg         we;
    reg  [3:0]  be;
    reg  [31:0] addr;
    reg  [31:0] wdata;
    wire [31:0] rdata;

    reg  [31:0] btn;

    integer pass_cnt;
    integer fail_cnt;
    reg [31:0] rd;

    btn_cont dut (
        .clk(clk),
        .rst_n(rst_n),
        .cs(cs),
        .we(we),
        .be(be),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .btn(btn)
    );

    always #5 clk = ~clk;

    task mmio_write;
        input [31:0] t_addr;
        input [31:0] t_data;
        input [3:0]  t_be;
        begin
            @(negedge clk);
            cs    = 1'b1;
            we    = 1'b1;
            be    = t_be;
            addr  = t_addr;
            wdata = t_data;
            @(posedge clk);
            #1;
            cs    = 1'b0;
            we    = 1'b0;
            be    = 4'h0;
            addr  = 32'h0;
            wdata = 32'h0;
        end
    endtask

    task mmio_read;
        input  [31:0] t_addr;
        output [31:0] t_data;
        begin
            @(negedge clk);
            cs   = 1'b1;
            we   = 1'b0;
            be   = 4'h0;
            addr = t_addr;
            #1;
            t_data = rdata;
            @(posedge clk);
            #1;
            cs   = 1'b0;
            addr = 32'h0;
        end
    endtask

    task expect_eq;
        input [31:0] got;
        input [31:0] exp;
        input [255:0] tag;
        begin
            if (got === exp) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0s: got=0x%08h", tag, got);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0s: got=0x%08h exp=0x%08h", tag, got, exp);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cs = 1'b0;
        we = 1'b0;
        be = 4'h0;
        addr = 32'h0;
        wdata = 32'h0;
        btn = 32'h0000_0000;
        pass_cnt = 0;
        fail_cnt = 0;

        $display("========================================");
        $display("Button Controller Standalone Simulation");
        $display("========================================");

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        mmio_read(BTN_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'h0000_0000, "DATA after reset");

        mmio_read(BTN_BASE_ADDR + REG_EDGE_OFF, rd);
        expect_eq(rd, 32'h0000_0000, "EDGE after reset");

        btn = 32'h0000_0005;
        @(posedge clk);

        mmio_read(BTN_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'h0000_0005, "DATA reflects inputs");

        mmio_read(BTN_BASE_ADDR + REG_EDGE_OFF, rd);
        expect_eq(rd, 32'h0000_0005, "EDGE captures rising transitions");

        mmio_write(BTN_BASE_ADDR + REG_EDGE_OFF, 32'h0000_0001, 4'h1);
        mmio_read(BTN_BASE_ADDR + REG_EDGE_OFF, rd);
        expect_eq(rd, 32'h0000_0004, "EDGE write-1-to-clear low byte");

        btn = 32'h0000_0004;
        @(posedge clk);
        mmio_read(BTN_BASE_ADDR + REG_EDGE_OFF, rd);
        expect_eq(rd, 32'h0000_0005, "EDGE captures falling transition");

        btn = 32'hA500_00F0;
        @(posedge clk);

        mmio_read(BTN_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'hA500_00F0, "DATA follows full 32-bit bitmap");

        mmio_read(BTN_BASE_ADDR + REG_EDGE_OFF, rd);
        expect_eq(rd, 32'hA500_00F5, "EDGE accumulates transitions");

        mmio_write(BTN_BASE_ADDR + REG_EDGE_OFF, 32'hFF00_0000, 4'h8);
        mmio_read(BTN_BASE_ADDR + REG_EDGE_OFF, rd);
        expect_eq(rd, 32'h0000_00F5, "EDGE clear respects byte enable");

        cs   = 1'b0;
        we   = 1'b0;
        addr = BTN_BASE_ADDR + REG_EDGE_OFF;
        #1;
        expect_eq(rdata, 32'h0000_0000, "RDATA is zero when cs deasserted");
        addr = 32'h0;

        $display("----------------------------------------");
        $display("PASS = %0d, FAIL = %0d", pass_cnt, fail_cnt);
        $display("----------------------------------------");

        if (fail_cnt == 0) begin
            $display("Button controller test PASSED");
        end else begin
            $display("Button controller test FAILED");
        end

        #20;
        $finish;
    end

endmodule