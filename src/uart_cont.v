`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UART Controller (MMIO)
//
// Register map (offset from UART_BASE_ADDR):
//   0x00 TXDATA   [7:0]  write to send one byte (ignored when TX busy)
//   0x04 RXDATA   [7:0]  read received byte (read clears rx_valid)
//   0x08 STATUS   [0]tx_ready [1]rx_valid
//   0x0C CTRL     [0]tx_irq_en [1]rx_irq_en
//   0x10 BAUD_DIV clocks per bit (minimum 1)
//////////////////////////////////////////////////////////////////////////////////

module uart_cont #(
    parameter integer DEFAULT_BAUD_DIV = 434 // 50MHz / 115200 ~= 434
)(
    input  wire        clk,
    input  wire        rst_n,

    // MMIO slave interface (single-cycle style)
    input  wire        cs,
    input  wire        we,
    input  wire [3:0]  be,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    // UART pins
    input  wire        uart_rx,
    output wire        uart_tx,

    // Optional interrupt output
    output wire        uart_irq
);

    localparam [5:0] REG_TXDATA   = 6'h00;
    localparam [5:0] REG_RXDATA   = 6'h04;
    localparam [5:0] REG_STATUS   = 6'h08;
    localparam [5:0] REG_CTRL     = 6'h0C;
    localparam [5:0] REG_BAUD_DIV = 6'h10;

    wire [5:0] reg_off = addr[5:0];
    wire wr_en = cs && we;
    wire rd_en = cs && !we;

    // ---------------- Register bank ----------------
    reg [31:0] baud_div_reg;
    reg [1:0]  ctrl_reg;

    reg [7:0]  rx_data_reg;
    reg        rx_valid_reg;

    // ---------------- TX datapath ----------------
    reg        tx_busy;
    reg [9:0]  tx_shift;
    reg [3:0]  tx_bit_cnt;
    reg [31:0] tx_clk_cnt;

    wire tx_ready = ~tx_busy;
    wire [31:0] baud_div_eff = (baud_div_reg == 32'd0) ? 32'd1 : baud_div_reg;

    assign uart_tx = tx_busy ? tx_shift[0] : 1'b1;

    // ---------------- RX synchronizer ----------------
    reg rx_sync_0;
    reg rx_sync_1;
    reg rx_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
            rx_prev   <= 1'b1;
        end else begin
            rx_sync_0 <= uart_rx;
            rx_sync_1 <= rx_sync_0;
            rx_prev   <= rx_sync_1;
        end
    end

    wire rx_fall = rx_prev && ~rx_sync_1;

    // ---------------- RX state machine ----------------
    localparam [1:0] RX_IDLE  = 2'd0;
    localparam [1:0] RX_START = 2'd1;
    localparam [1:0] RX_DATA  = 2'd2;
    localparam [1:0] RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [2:0]  rx_bit_cnt;
    reg [31:0] rx_clk_cnt;
    reg [7:0]  rx_shift;

    // ---------------- MMIO read mux ----------------
    always @(*) begin
        rdata = 32'h0000_0000;
        if (cs) begin
            case (reg_off)
                REG_TXDATA:   rdata = 32'h0000_0000;
                REG_RXDATA:   rdata = {24'h0, rx_data_reg};
                REG_STATUS:   rdata = {30'h0, rx_valid_reg, tx_ready};
                REG_CTRL:     rdata = {30'h0, ctrl_reg};
                REG_BAUD_DIV: rdata = baud_div_reg;
                default:      rdata = 32'h0000_0000;
            endcase
        end
    end

    assign uart_irq = (ctrl_reg[0] && tx_ready) || (ctrl_reg[1] && rx_valid_reg);

    // ---------------- Sequential logic ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_reg <= (DEFAULT_BAUD_DIV <= 0) ? 32'd1 : DEFAULT_BAUD_DIV[31:0];
            ctrl_reg     <= 2'b00;

            rx_data_reg  <= 8'h00;
            rx_valid_reg <= 1'b0;

            tx_busy      <= 1'b0;
            tx_shift     <= 10'h3FF;
            tx_bit_cnt   <= 4'd0;
            tx_clk_cnt   <= 32'd0;

            rx_state     <= RX_IDLE;
            rx_bit_cnt   <= 3'd0;
            rx_clk_cnt   <= 32'd0;
            rx_shift     <= 8'h00;
        end else begin
            // -------- MMIO write path --------
            if (wr_en) begin
                case (reg_off)
                    REG_TXDATA: begin
                        if (tx_ready && (|be)) begin
                            tx_busy    <= 1'b1;
                            tx_shift   <= {1'b1, wdata[7:0], 1'b0};
                            tx_bit_cnt <= 4'd0;
                            tx_clk_cnt <= 32'd0;
                        end
                    end
                    REG_CTRL: begin
                        if (be[0]) begin
                            ctrl_reg <= wdata[1:0];
                        end
                    end
                    REG_BAUD_DIV: begin
                        if (be[0]) baud_div_reg[7:0]   <= wdata[7:0];
                        if (be[1]) baud_div_reg[15:8]  <= wdata[15:8];
                        if (be[2]) baud_div_reg[23:16] <= wdata[23:16];
                        if (be[3]) baud_div_reg[31:24] <= wdata[31:24];
                    end
                    default: begin
                    end
                endcase
            end

            // Reading RXDATA clears rx_valid (consume event)
            if (rd_en && (reg_off == REG_RXDATA)) begin
                rx_valid_reg <= 1'b0;
            end

            // -------- TX engine --------
            if (tx_busy) begin
                if (tx_clk_cnt >= (baud_div_eff - 1)) begin
                    tx_clk_cnt <= 32'd0;
                    if (tx_bit_cnt == 4'd9) begin
                        tx_busy    <= 1'b0;
                        tx_bit_cnt <= 4'd0;
                    end else begin
                        tx_shift   <= {1'b1, tx_shift[9:1]};
                        tx_bit_cnt <= tx_bit_cnt + 4'd1;
                    end
                end else begin
                    tx_clk_cnt <= tx_clk_cnt + 32'd1;
                end
            end

            // -------- RX engine --------
            case (rx_state)
                RX_IDLE: begin
                    if (rx_fall) begin
                        rx_state   <= RX_START;
                        rx_clk_cnt <= (baud_div_eff >> 1);
                    end
                end

                RX_START: begin
                    if (rx_clk_cnt == 32'd0) begin
                        if (~rx_sync_1) begin
                            rx_state   <= RX_DATA;
                            rx_bit_cnt <= 3'd0;
                            rx_clk_cnt <= baud_div_eff - 1;
                        end else begin
                            // False start bit
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt - 32'd1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt == 32'd0) begin
                        rx_shift[rx_bit_cnt] <= rx_sync_1;
                        if (rx_bit_cnt == 3'd7) begin
                            rx_state   <= RX_STOP;
                            rx_clk_cnt <= baud_div_eff - 1;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 3'd1;
                            rx_clk_cnt <= baud_div_eff - 1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt - 32'd1;
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt == 32'd0) begin
                        if (rx_sync_1) begin
                            rx_data_reg  <= rx_shift;
                            rx_valid_reg <= 1'b1;
                        end
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt - 32'd1;
                    end
                end

                default: begin
                    rx_state <= RX_IDLE;
                end
            endcase
        end
    end

endmodule
