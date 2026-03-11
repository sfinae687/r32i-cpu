`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_uart_cpu_rx
//
// Description: CPU UART RX integration example.
//              Loads uart_echo.hex, injects bytes on uart_rx,
//              and verifies the CPU echoes them on uart_tx.
//////////////////////////////////////////////////////////////////////////////////

module tb_uart_cpu_rx;

    localparam integer CLK_PERIOD = 10;   // 100 MHz
    localparam integer BAUD_DIV   = 16;   // keep simulation short
    localparam integer BIT_TIME   = CLK_PERIOD * BAUD_DIV;

    localparam [31:0] UART_BASE = 32'h1000_0000;

    // DUT signals
    reg         clk;
    reg         rst_n;
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_addr_byte;

    reg         uart_rx;
    wire        uart_tx;
    wire        uart_irq;

    wire        uart_cs;
    wire        ram_cs;
    wire [31:0] uart_rdata;
    wire [31:0] ram_rdata;

    integer i;
    integer tx_count;
    reg [7:0] expected [0:3];
    reg [7:0] got [0:3];

    // Clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // CPU
    cpu cpu_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be)
    );

    // Program: uart_echo.hex
    imem #(
        .ADDR_WIDTH (10),
        .DATA_WIDTH (32),
        .FILE_INIT  ("/home/ll06/info/cpu_sources/prog/uart_echo.hex")
    ) imem_inst (
        .addr       (imem_addr[11:2]),
        .dout       (imem_rdata)
    );

    // DRAM
    dram #(
        .ADDR_WIDTH (10),
        .DATA_WIDTH (32)
    ) dram_inst (
        .clk        (clk),
        .we         (dmem_we && ram_cs),
        .byte_we    (dmem_be),
        .addr       (dmem_addr[9:0]),
        .din        (dmem_wdata),
        .dout       (ram_rdata)
    );

    // UART MMIO
    uart_cont #(
        .DEFAULT_BAUD_DIV (BAUD_DIV)
    ) uart_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .cs         (uart_cs),
        .we         (dmem_we),
        .be         (dmem_be),
        .addr       (dmem_addr_byte),
        .wdata      (dmem_wdata),
        .rdata      (uart_rdata),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .uart_irq   (uart_irq)
    );

    assign dmem_addr_byte = {dmem_addr[29:0], 2'b00};
    assign ram_cs  = (dmem_addr_byte < UART_BASE);
    assign uart_cs = (dmem_addr_byte >= UART_BASE && dmem_addr_byte < UART_BASE + 32'h100);
    assign dmem_rdata = uart_cs ? uart_rdata : ram_rdata;

    // Drive one byte into DUT uart_rx (8N1, LSB first)
    task send_rx_byte;
        input [7:0] b;
        integer bit_idx;
        begin
            uart_rx = 1'b1;
            #BIT_TIME;

            uart_rx = 1'b0; // start bit
            #BIT_TIME;

            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx = b[bit_idx];
                #BIT_TIME;
            end

            uart_rx = 1'b1; // stop bit
            #BIT_TIME;
        end
    endtask

    // Decode one byte from DUT uart_tx
    task recv_tx_byte;
        output [7:0] b;
        integer bit_idx;
        begin
            wait (uart_tx == 1'b0);
            #(BIT_TIME / 2);

            if (uart_tx !== 1'b0) begin
                b = 8'hFF;
            end else begin
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    #BIT_TIME;
                    b[bit_idx] = uart_tx;
                end
                #BIT_TIME; // stop bit
            end
        end
    endtask

    initial begin
        // Expect echo of 'O', 'K', '\r', then extra '\n' from program
        expected[0] = 8'h4F;
        expected[1] = 8'h4B;
        expected[2] = 8'h0D;
        expected[3] = 8'h0A;

        rst_n = 1'b0;
        uart_rx = 1'b1;
        tx_count = 0;
        prev_uart_status = 32'hFFFF_FFFF; // sentinel: force print on first real value

        $dumpfile("tb_uart_cpu_rx.vcd");
        $dumpvars(0, tb_uart_cpu_rx);

        $display("========================================");
        $display("UART CPU RX Integration Test");
        $display("Program: uart_echo.hex");
        $display("Inject:  'O' 'K' '\\r'");
        $display("Expect:  'O' 'K' '\\r' '\\n'");
        $display("========================================");

        if ((imem_inst.mem[0] == 32'h00000013) &&
            (imem_inst.mem[1] == 32'h00000013) &&
            (imem_inst.mem[2] == 32'h00000013) &&
            (imem_inst.mem[3] == 32'h00000013)) begin
            $display("[FAIL] IMEM appears to be all NOPs. uart_echo.hex was not loaded.");
            $finish;
        end

        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        #(CLK_PERIOD * 10);

        // ---- Initial state snapshot after reset ----
        $display("[INIT] PC=0x%08h  UART.STATUS=0x%08h  tx_ready=%b  rx_valid=%b  baud_div=%0d",
                 cpu_inst.pc,
                 uart_inst.rdata,
                 uart_inst.tx_ready,
                 uart_inst.rx_valid_reg,
                 uart_inst.baud_div_reg);

        fork
            begin
                // Give CPU time to enter receive loop, then inject input bytes
                #(BIT_TIME * 4);
                send_rx_byte(8'h4F); // 'O'
                #(BIT_TIME * 2);
                send_rx_byte(8'h4B); // 'K'
                #(BIT_TIME * 2);
                send_rx_byte(8'h0D); // '\r'
            end

            begin
                while (tx_count < 4) begin
                    recv_tx_byte(got[tx_count]);
                    if (got[tx_count] >= 8'd32 && got[tx_count] < 8'd127) begin
                        $display("[%t] TX[%0d] = 0x%02h '%c'", $time, tx_count, got[tx_count], got[tx_count]);
                    end else begin
                        $display("[%t] TX[%0d] = 0x%02h '.'", $time, tx_count, got[tx_count]);
                    end
                    tx_count = tx_count + 1;
                end
            end
        join

        $display("----------------------------------------");
        for (i = 0; i < 4; i = i + 1) begin
            if (got[i] == expected[i]) begin
                $display("[PASS] byte[%0d]: got=0x%02h exp=0x%02h", i, got[i], expected[i]);
            end else begin
                $display("[FAIL] byte[%0d]: got=0x%02h exp=0x%02h", i, got[i], expected[i]);
            end
        end
        $display("----------------------------------------");

        #(CLK_PERIOD * 50);
        $finish;
    end

    initial begin
        #(BIT_TIME * 300);
        $display("[TIMEOUT] tb_uart_cpu_rx timeout");
        $finish;
    end

    // =========================================================================
    // Monitor 1: UART MMIO bus
    //   - Always log writes
    //   - Log non-STATUS reads always
    //   - Log STATUS reads only when the value changes (suppress poll noise)
    // =========================================================================
    reg [31:0] prev_uart_status;
    always @(posedge clk) begin
        if (rst_n && uart_cs) begin
            if (dmem_we) begin
                $display("[%t] [MMIO WR] addr=0x%08h data=0x%08h be=%04b  PC=0x%08h",
                         $time, dmem_addr_byte, dmem_wdata, dmem_be, cpu_inst.pc);
            end else begin
                if (dmem_addr_byte[5:0] != 6'h08) begin
                    // Non-STATUS read: always print
                    $display("[%t] [MMIO RD] addr=0x%08h rdata=0x%08h         PC=0x%08h",
                             $time, dmem_addr_byte, uart_rdata, cpu_inst.pc);
                end else if (uart_rdata !== prev_uart_status) begin
                    // STATUS read: only print on value change
                    $display("[%t] [MMIO RD] STATUS 0x%08h->0x%08h  tx_ready=%b rx_valid=%b  PC=0x%08h",
                             $time, prev_uart_status, uart_rdata,
                             uart_rdata[0], uart_rdata[1], cpu_inst.pc);
                    prev_uart_status <= uart_rdata;
                end
            end
        end
    end

    // =========================================================================
    // Monitor 2: UART RX state machine transitions
    // =========================================================================
    reg [1:0] prev_rx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_rx_state <= 2'd0;
        end else if (uart_inst.rx_state !== prev_rx_state) begin
            $display("[%t] [UART RX] state %0d->%0d  bit=%0d  rx_valid=%b  rx_data=0x%02h  uart_rx=%b",
                     $time,
                     prev_rx_state, uart_inst.rx_state,
                     uart_inst.rx_bit_cnt,
                     uart_inst.rx_valid_reg,
                     uart_inst.rx_data_reg,
                     uart_rx);
            prev_rx_state <= uart_inst.rx_state;
        end
    end

    // =========================================================================
    // Monitor 3: CPU register file writes
    //   Skip polling scratch registers: x1(ra), x5(t0=UART base), x7(t2=poll temp)
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n && cpu_inst.reg_wr && (cpu_inst.rd != 5'd0) &&
            (cpu_inst.rd != 5'd1) &&   // ra: return address churn
            (cpu_inst.rd != 5'd5) &&   // t0: UART base (set once, verbose)
            (cpu_inst.rd != 5'd7))     // t2: STATUS poll scratch
            $display("[%t] [REG WR ] x%02d <- 0x%08h  PC=0x%08h",
                     $time, cpu_inst.rd, cpu_inst.reg_wr_data, cpu_inst.pc);
    end

endmodule
