`timescale 1ns / 1ps

module tb_seg7_cont;

    localparam [31:0] LED_BASE_ADDR = 32'h1000_0220;
    localparam [31:0] REG_DATA_OFF  = 32'h0000_0000;
    localparam [31:0] REG_SET_OFF   = 32'h0000_0004;
    localparam [31:0] REG_CLR_OFF   = 32'h0000_0008;

    reg         clk;
    reg         rst_n;
    reg         cs;
    reg         we;
    reg  [3:0]  be;
    reg  [31:0] addr;
    reg  [31:0] wdata;
    wire [31:0] rdata;
    wire [31:0] led;

    integer pass_cnt;
    integer fail_cnt;
    reg [31:0] rd;

    seg7_cont dut (
        .clk(clk),
        .rst_n(rst_n),
        .cs(cs),
        .we(we),
        .be(be),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .led(led)
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
        pass_cnt = 0;
        fail_cnt = 0;

        $display("========================================");
        $display("SEG7 Controller Standalone Simulation");
        $display("========================================");

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'h0000_0000, "DATA after reset");
        expect_eq(led, 32'h0000_0000, "LED output after reset");

        mmio_write(LED_BASE_ADDR + REG_DATA_OFF, 32'h0000_003F, 4'h1);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'h0000_003F, "DATA write low byte");
        expect_eq(led, 32'h0000_003F, "LED follows DATA");

        mmio_write(LED_BASE_ADDR + REG_SET_OFF, 32'h0000_0080, 4'h1);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'h0000_00BF, "SET sets selected bits");

        mmio_write(LED_BASE_ADDR + REG_CLR_OFF, 32'h0000_0001, 4'h1);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'h0000_00BE, "CLR clears selected bits");

        mmio_write(LED_BASE_ADDR + REG_DATA_OFF, 32'hA5A5_5A5A, 4'hF);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'hA5A5_5A5A, "DATA full-word write");

        mmio_write(LED_BASE_ADDR + REG_DATA_OFF, 32'h1122_3344, 4'h2);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'hA5A5_335A, "DATA byte-enable write");

        mmio_write(LED_BASE_ADDR + REG_SET_OFF, 32'h00FF_0000, 4'h4);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'hA5FF_335A, "SET respects byte enable");

        mmio_write(LED_BASE_ADDR + REG_CLR_OFF, 32'h0000_FF00, 4'h2);
        mmio_read(LED_BASE_ADDR + REG_DATA_OFF, rd);
        expect_eq(rd, 32'hA5FF_005A, "CLR respects byte enable");

        cs   = 1'b0;
        we   = 1'b0;
        addr = LED_BASE_ADDR + REG_DATA_OFF;
        #1;
        expect_eq(rdata, 32'h0000_0000, "RDATA is zero when cs deasserted");
        addr = 32'h0;

        $display("----------------------------------------");
        $display("PASS = %0d, FAIL = %0d", pass_cnt, fail_cnt);
        $display("----------------------------------------");

        if (fail_cnt == 0) begin
            $display("SEG7 controller test PASSED");
        end else begin
            $display("SEG7 controller test FAILED");
        end

        #20;
        $finish;
    end

endmodule
