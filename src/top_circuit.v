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


module top_circuit(
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

    // CPU dmem_addr uses word addressing; reconstruct aligned byte address for decoding/MMIO.
    wire [31:0] dmem_addr_byte = {dmem_addr, 2'b00};
    wire [31:0] RAM_BASE_WORD  = RAM_BASE_ADDR[31:2];
    wire [31:0] dmem_ram_word_addr = dmem_addr - RAM_BASE_WORD;

    // Per-device register offsets (runtime.h)
    localparam [3:0] BTN_REG_DATA_OFF = 4'h0;
    localparam [3:0] BTN_REG_EDGE_OFF = 4'h4;
    localparam [3:0] LED_REG_DATA_OFF = 4'h0;
    localparam [3:0] LED_REG_SET_OFF  = 4'h4;
    localparam [3:0] LED_REG_CLR_OFF  = 4'h8;

    // -------------------------------------------------------------------------
    // Address decode
    // -------------------------------------------------------------------------
    wire hit_ram   = (dmem_addr_byte >= RAM_BASE_ADDR)  && (dmem_addr_byte <= RAM_END_ADDR);
    wire hit_mmio  = (dmem_addr_byte >= MMIO_BASE_ADDR) && (dmem_addr_byte <= MMIO_END_ADDR);
    wire hit_uart  = hit_mmio && (dmem_addr_byte >= UART_BASE_ADDR) && (dmem_addr_byte <= UART_END_ADDR);
    wire hit_btn   = hit_mmio && (dmem_addr_byte >= BTN_BASE_ADDR)  && (dmem_addr_byte <= BTN_END_ADDR);
    wire hit_led   = hit_mmio && (dmem_addr_byte >= LED_BASE_ADDR)  && (dmem_addr_byte <= LED_END_ADDR);

    // runtime.h stride convention: dev index in addr[5:4], reg offset in addr[3:0]
    wire [1:0] btn_dev_idx = dmem_addr_byte[5:4];
    wire [1:0] led_dev_idx = dmem_addr_byte[5:4];
    wire [3:0] btn_reg_off = dmem_addr_byte[3:0];
    wire [3:0] led_reg_off = dmem_addr_byte[3:0];

    // -------------------------------------------------------------------------
    // Memory return buses from each target
    // -------------------------------------------------------------------------
    wire [31:0] ram_rdata;
    wire [31:0] uart_rdata;
    wire [31:0] btn_rdata;
    wire [31:0] led_rdata;

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

    imem imem_inst(
        .addr (imem_addr[11:2]),  // Convert byte address to word address (10-bit index)
        .dout (imem_rdata)
    );

    dram #(
        .ADDR_WIDTH (10),
        .DATA_WIDTH (32)
    ) dmem_inst(
        .clk (clk),
        .we (dmem_we && hit_ram),
        .byte_we (dmem_be),
        .addr (dmem_ram_word_addr[9:0]),
        .din (dmem_wdata),
        .dout (ram_rdata)
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
    // GPIO MMIO reservation (controllers intentionally not implemented)
    // -------------------------------------------------------------------------
    // NOTE:
    //   btn_cont / led_cont are intentionally NOT implemented in this revision.
    //   Only address-map and bus hookup points are kept, so runtime.h mapping
    //   remains stable and can be connected later without changing CPU side.
    wire        btn_cs = hit_btn;
    wire        led_cs = hit_led;
    wire        gpio_we = dmem_we;
    wire [3:0]  gpio_be = dmem_be;
    wire [31:0] gpio_addr = dmem_addr_byte;
    wire [31:0] gpio_wdata = dmem_wdata;

    // Placeholder behavior until dedicated LED controller is added at this location.
    assign led0 = 32'h0000_0000;
    assign led1 = 32'h0000_0000;
    assign led2 = 32'h0000_0000;
    assign led3 = 32'h0000_0000;

    // Placeholder readback values until dedicated GPIO controllers are added here.
    // Kept as fixed zero to avoid side effects before real controllers are connected.
    assign btn_rdata = 32'h0000_0000;
    assign led_rdata = 32'h0000_0000;

    // ---------------- GPIO controller placement template ----------------
    // btn_cont btn_ctrl_inst (
    //     .clk   (clk),
    //     .rst_n (rst_n_i),
    //     .cs    (btn_cs),
    //     .we    (gpio_we),
    //     .be    (gpio_be),
    //     .addr  (gpio_addr),
    //     .wdata (gpio_wdata),
    //     .rdata (btn_rdata),
    //     // addr decode usage example:
    //     // .dev_idx(btn_dev_idx), .reg_off(btn_reg_off)
    //     .btn0  (btn0),
    //     .btn1  (btn1),
    //     .btn2  (btn2),
    //     .btn3  (btn3)
    // );
    //
    // led_cont led_ctrl_inst (
    //     .clk   (clk),
    //     .rst_n (rst_n_i),
    //     .cs    (led_cs),
    //     .we    (gpio_we),
    //     .be    (gpio_be),
    //     .addr  (gpio_addr),
    //     .wdata (gpio_wdata),
    //     .rdata (led_rdata),
    //     // addr decode usage example:
    //     // .dev_idx(led_dev_idx), .reg_off(led_reg_off)
    //     .led0  (led0),
    //     .led1  (led1),
    //     .led2  (led2),
    //     .led3  (led3)
    // );

    // -------------------------------------------------------------------------
    // CPU read-data mux
    // -------------------------------------------------------------------------
    assign cpu_dmem_rdata = hit_ram  ? ram_rdata :
                            hit_uart ? uart_rdata :
                            hit_btn  ? btn_rdata :
                            hit_led  ? led_rdata :
                            32'h0000_0000;
    
endmodule
