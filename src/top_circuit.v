`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/03 12:48:51
// Design Name: 
// Module Name: top_circuit
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


module top_circuit #(
    // Default program image for IMEM. Keep empty to preserve previous behavior.
    parameter [1023:0] IMEM_FILE_INIT = ""
)(
    input  wire        clk,
    input  wire        rst_n,

    // UART external pins
    input  wire        uart_rx,
    output wire        uart_tx,
    output wire        uart_irq,

    // GPIO external pin interface (directly connected to board pins)
    // 4x button devices (each 32-bit bitmap)
    // runtime.h mapping:
    //   btn0 <-> BTN_BASE_ADDR + 0 * BTN_STRIDE
    //   btn1 <-> BTN_BASE_ADDR + 1 * BTN_STRIDE
    //   btn2 <-> BTN_BASE_ADDR + 2 * BTN_STRIDE
    //   btn3 <-> BTN_BASE_ADDR + 3 * BTN_STRIDE
    // bit meaning matches BTN_REG_DATA_OFF: bit[k]=1 means button k is pressed.
    input  wire [31:0] btn0,
    input  wire [31:0] btn1,
    input  wire [31:0] btn2,
    input  wire [31:0] btn3,

    // 4x LED devices (each 32-bit bitmap)
    // runtime.h mapping:
    //   led0 <-> LED_BASE_ADDR + 0 * LED_STRIDE
    //   led1 <-> LED_BASE_ADDR + 1 * LED_STRIDE
    //   led2 <-> LED_BASE_ADDR + 2 * LED_STRIDE
    //   led3 <-> LED_BASE_ADDR + 3 * LED_STRIDE
    // bit meaning matches LED_REG_DATA_OFF: bit[k] drives LED k state.
    output wire [31:0] led0,
    output wire [31:0] led1,
    output wire [31:0] led2,
    output wire [31:0] led3
    );

    // Legacy/simple testbenches may leave these top-level pins floating.
    wire rst_n_i   = (rst_n   === 1'bz) ? 1'b1 : rst_n;
    wire uart_rx_i = (uart_rx === 1'bz) ? 1'b1 : uart_rx;

    // -------------------------------------------------------------------------
    // CPU memory interfaces
    // -------------------------------------------------------------------------
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] cpu_dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;

    // -------------------------------------------------------------------------
    // Address map (must match prog/runtime.h)
    // -------------------------------------------------------------------------
    localparam [31:0] RAM_BASE_ADDR   = 32'h0000_1000;
    localparam [31:0] RAM_SIZE_BYTES  = 32'h0000_1000;
    localparam [31:0] RAM_END_ADDR    = RAM_BASE_ADDR + RAM_SIZE_BYTES - 1;

    localparam [31:0] MMIO_BASE_ADDR  = 32'h1000_0000;
    localparam [31:0] MMIO_SIZE_BYTES = 32'h0000_1000;
    localparam [31:0] MMIO_END_ADDR   = MMIO_BASE_ADDR + MMIO_SIZE_BYTES - 1;

    // UART: 0x1000_0000 ~ 0x1000_001F
    localparam [31:0] UART_BASE_ADDR  = 32'h1000_0000;
    localparam [31:0] UART_END_ADDR   = 32'h1000_001F;

    // BTN: 4 devices, stride 0x10 -> 0x1000_0100 ~ 0x1000_013F
    localparam [31:0] BTN_BASE_ADDR   = 32'h1000_0100;
    localparam [31:0] BTN_END_ADDR    = 32'h1000_013F;

    // LED: 4 devices, stride 0x10 -> 0x1000_0200 ~ 0x1000_023F
    localparam [31:0] LED_BASE_ADDR   = 32'h1000_0200;
    localparam [31:0] LED_END_ADDR    = 32'h1000_023F;

    // Memory controller outputs
    wire [31:0] dmem_addr_byte;
    wire        hit_mem_imem;
    wire        hit_mem_dram;

    // -------------------------------------------------------------------------
    // Address decode
    // -------------------------------------------------------------------------
    wire hit_ram   = hit_mem_dram;
    wire hit_mmio  = (dmem_addr_byte >= MMIO_BASE_ADDR) && (dmem_addr_byte <= MMIO_END_ADDR);
    wire hit_uart  = hit_mmio && (dmem_addr_byte >= UART_BASE_ADDR) && (dmem_addr_byte <= UART_END_ADDR);
    wire hit_btn   = hit_mmio && (dmem_addr_byte >= BTN_BASE_ADDR)  && (dmem_addr_byte <= BTN_END_ADDR);
    wire hit_led   = hit_mmio && (dmem_addr_byte >= LED_BASE_ADDR)  && (dmem_addr_byte <= LED_END_ADDR);

    // runtime.h stride convention: dev index in addr[5:4], reg offset in addr[3:0]
    wire [1:0] btn_dev_idx = dmem_addr_byte[5:4];
    wire [1:0] led_dev_idx = dmem_addr_byte[5:4];
    // -------------------------------------------------------------------------
    // Memory return buses from each target
    // -------------------------------------------------------------------------
    wire [31:0] mem_rdata;
    wire [31:0] uart_rdata;
    wire [31:0] btn_rdata;
    wire [31:0] led_rdata;
    wire [31:0] btn_rdata0;
    wire [31:0] btn_rdata1;
    wire [31:0] btn_rdata2;
    wire [31:0] btn_rdata3;
    wire [31:0] led_rdata0;
    wire [31:0] led_rdata1;
    wire [31:0] led_rdata2;
    wire [31:0] led_rdata3;
    wire [31:0] led_data0;
    wire [31:0] led_data1;
    wire [31:0] led_data2;
    wire [31:0] led_data3;

    // -------------------------------------------------------------------------
    // Core + memory/peripheral instances
    // -------------------------------------------------------------------------
    cpu cpu_inst(
        .clk (clk),
        .rst_n (rst_n_i),
        .imem_addr (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (cpu_dmem_rdata),
        .dmem_we (dmem_we),
        .dmem_be (dmem_be)
    );

    mem_cont #(
        .IMEM_ADDR_WIDTH (10),
        .DMEM_ADDR_WIDTH (10),
        .DATA_WIDTH      (32),
        .IMEM_FILE_INIT  (IMEM_FILE_INIT)
    ) mem_ctrl_inst(
        .clk (clk),
        .imem_addr      (imem_addr),
        .imem_rdata     (imem_rdata),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_we        (dmem_we),
        .dmem_be        (dmem_be),
        .dmem_rdata     (mem_rdata),
        .dmem_addr_byte (dmem_addr_byte),
        .hit_imem       (hit_mem_imem),
        .hit_dram       (hit_mem_dram)
    );

    uart_cont uart_inst(
        .clk     (clk),
        .rst_n   (rst_n_i),
        .cs      (hit_uart),
        .we      (dmem_we),
        .be      (dmem_be),
        .addr    (dmem_addr_byte),
        .wdata   (dmem_wdata),
        .rdata   (uart_rdata),
        .uart_rx (uart_rx_i),
        .uart_tx (uart_tx),
        .uart_irq(uart_irq)
    );

    // -------------------------------------------------------------------------
    // GPIO MMIO controllers
    // -------------------------------------------------------------------------
    // Buttons/LEDs are implemented as one controller per runtime device.
    wire        btn_cs = hit_btn;
    wire        led_cs = hit_led;
    wire        gpio_we = dmem_we;
    wire [3:0]  gpio_be = dmem_be;
    wire [31:0] gpio_addr = dmem_addr_byte;
    wire [31:0] gpio_wdata = dmem_wdata;
    wire        btn_cs0 = btn_cs && (btn_dev_idx == 2'd0);
    wire        btn_cs1 = btn_cs && (btn_dev_idx == 2'd1);
    wire        btn_cs2 = btn_cs && (btn_dev_idx == 2'd2);
    wire        btn_cs3 = btn_cs && (btn_dev_idx == 2'd3);
    wire        led_cs0 = led_cs && (led_dev_idx == 2'd0);
    wire        led_cs1 = led_cs && (led_dev_idx == 2'd1);
    wire        led_cs2 = led_cs && (led_dev_idx == 2'd2);
    wire        led_cs3 = led_cs && (led_dev_idx == 2'd3);

    btn_cont btn_ctrl_inst0 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (btn_cs0),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (btn_rdata0),
        .btn   (btn0)
    );

    btn_cont btn_ctrl_inst1 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (btn_cs1),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (btn_rdata1),
        .btn   (btn1)
    );

    btn_cont btn_ctrl_inst2 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (btn_cs2),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (btn_rdata2),
        .btn   (btn2)
    );

    btn_cont btn_ctrl_inst3 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (btn_cs3),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (btn_rdata3),
        .btn   (btn3)
    );

    assign btn_rdata = (btn_dev_idx == 2'd0) ? btn_rdata0 :
                       (btn_dev_idx == 2'd1) ? btn_rdata1 :
                       (btn_dev_idx == 2'd2) ? btn_rdata2 :
                                               btn_rdata3;

    seg7_cont seg7_ctrl_inst0 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (led_cs0),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (led_rdata0),
        .led   (led_data0)
    );

    seg7_cont seg7_ctrl_inst1 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (led_cs1),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (led_rdata1),
        .led   (led_data1)
    );

    seg7_cont seg7_ctrl_inst2 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (led_cs2),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (led_rdata2),
        .led   (led_data2)
    );

    seg7_cont seg7_ctrl_inst3 (
        .clk   (clk),
        .rst_n (rst_n_i),
        .cs    (led_cs3),
        .we    (gpio_we),
        .be    (gpio_be),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .rdata (led_rdata3),
        .led   (led_data3)
    );

    assign led0 = led_data0;
    assign led1 = led_data1;
    assign led2 = led_data2;
    assign led3 = led_data3;

    assign led_rdata = (led_dev_idx == 2'd0) ? led_rdata0 :
                       (led_dev_idx == 2'd1) ? led_rdata1 :
                       (led_dev_idx == 2'd2) ? led_rdata2 :
                                               led_rdata3;

    // -------------------------------------------------------------------------
    // CPU read-data mux
    // -------------------------------------------------------------------------
    assign cpu_dmem_rdata = hit_ram  ? mem_rdata :
                            hit_uart ? uart_rdata :
                            hit_btn  ? btn_rdata :
                            hit_led  ? led_rdata :
                            32'h0000_0000;

`ifndef SYNTHESIS
    // Simulation-only override:
    //   +PROG=/abs/path/to/program.hex
    // This allows loading a custom program file without editing the testbench.
    reg [1023:0] sim_prog_file;
    initial begin
        if ($value$plusargs("PROG=%s", sim_prog_file)) begin
            mem_ctrl_inst.imem_inst.clear_to_nop();
            $readmemh(sim_prog_file, mem_ctrl_inst.imem_inst.mem);
            $display("[top_circuit] Loaded IMEM from +PROG=%0s", sim_prog_file);
        end
    end
`endif
    
endmodule
