`timescale 1ns / 1ps

module btn_cont(
	input  wire        clk,
	input  wire        rst_n,
	input  wire        cs,
	input  wire        we,
	input  wire [3:0]  be,
	input  wire [31:0] addr,
	input  wire [31:0] wdata,
	output reg  [31:0] rdata,
	input  wire [31:0] btn
	);

	localparam [3:0] BTN_REG_DATA_OFF = 4'h0;
	localparam [3:0] BTN_REG_EDGE_OFF = 4'h4;

	reg [31:0] btn_prev;
	reg [31:0] edge_cap;

	wire [31:0] btn_change = btn ^ btn_prev;
	wire        edge_clr_en = cs && we && (addr[3:0] == BTN_REG_EDGE_OFF);
	wire [31:0] edge_clr_mask = {
		{8{be[3]}} & wdata[31:24],
		{8{be[2]}} & wdata[23:16],
		{8{be[1]}} & wdata[15:8],
		{8{be[0]}} & wdata[7:0]
	};

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			btn_prev  <= 32'h0000_0000;
			edge_cap  <= 32'h0000_0000;
		end else begin
			btn_prev <= btn;
			edge_cap <= (edge_cap | btn_change) & ~(edge_clr_en ? edge_clr_mask : 32'h0000_0000);
		end
	end

	always @(*) begin
		rdata = 32'h0000_0000;

		if (cs) begin
			case (addr[3:0])
				BTN_REG_DATA_OFF: rdata = btn;
				BTN_REG_EDGE_OFF: rdata = edge_cap;
				default:          rdata = 32'h0000_0000;
			endcase
		end
	end

endmodule
