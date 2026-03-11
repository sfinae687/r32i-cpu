`timescale 1ns / 1ps

module seg7_cont(
	input  wire        clk,
	input  wire        rst_n,
	input  wire        cs,
	input  wire        we,
	input  wire [3:0]  be,
	input  wire [31:0] addr,
	input  wire [31:0] wdata,
	output reg  [31:0] rdata,
	output wire [31:0] led
	);

	localparam [3:0] LED_REG_DATA_OFF = 4'h0;
	localparam [3:0] LED_REG_SET_OFF  = 4'h4;
	localparam [3:0] LED_REG_CLR_OFF  = 4'h8;

	reg [31:0] led_data;

	wire       data_wr_en = cs && we && (addr[3:0] == LED_REG_DATA_OFF);
	wire       set_wr_en  = cs && we && (addr[3:0] == LED_REG_SET_OFF);
	wire       clr_wr_en  = cs && we && (addr[3:0] == LED_REG_CLR_OFF);
	wire [31:0] be_mask   = {
		{8{be[3]}},
		{8{be[2]}},
		{8{be[1]}},
		{8{be[0]}}
	};
	wire [31:0] op_mask   = wdata & be_mask;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			led_data <= 32'h0000_0000;
		end else begin
			if (data_wr_en) begin
				led_data <= (led_data & ~be_mask) | op_mask;
			end else if (set_wr_en) begin
				led_data <= led_data | op_mask;
			end else if (clr_wr_en) begin
				led_data <= led_data & ~op_mask;
			end
		end
	end

	always @(*) begin
		rdata = 32'h0000_0000;

		if (cs) begin
			case (addr[3:0])
				LED_REG_DATA_OFF: rdata = led_data;
				LED_REG_SET_OFF:  rdata = led_data;
				LED_REG_CLR_OFF:  rdata = led_data;
				default:          rdata = 32'h0000_0000;
			endcase
		end
	end

	assign led = led_data;

endmodule
