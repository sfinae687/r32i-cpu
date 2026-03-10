`timescale 1ns / 1ps

module tb_uart_cont;

	localparam [31:0] REG_TXDATA   = 32'h0000_0000;
	localparam [31:0] REG_RXDATA   = 32'h0000_0004;
	localparam [31:0] REG_STATUS   = 32'h0000_0008;
	localparam [31:0] REG_CTRL     = 32'h0000_000C;
	localparam [31:0] REG_BAUD_DIV = 32'h0000_0010;

	localparam integer BIT_CYCLES = 8;

	reg         clk;
	reg         rst_n;
	reg         cs;
	reg         we;
	reg  [3:0]  be;
	reg  [31:0] addr;
	reg  [31:0] wdata;
	wire [31:0] rdata;

	reg         uart_rx;
	wire        uart_tx;
	wire        uart_irq;

	integer pass_cnt;
	integer fail_cnt;
	integer i;
	integer timeout;
	reg [31:0] rd;

	uart_cont #(
		.DEFAULT_BAUD_DIV(16)
	) dut (
		.clk(clk),
		.rst_n(rst_n),
		.cs(cs),
		.we(we),
		.be(be),
		.addr(addr),
		.wdata(wdata),
		.rdata(rdata),
		.uart_rx(uart_rx),
		.uart_tx(uart_tx),
		.uart_irq(uart_irq)
	);

	always #5 clk = ~clk;

	task mmio_write;
		input [31:0] t_addr;
		input [31:0] t_data;
		input [3:0]  t_be;
		begin
			@(negedge clk);
			cs   = 1'b1;
			we   = 1'b1;
			be   = t_be;
			addr = t_addr;
			wdata = t_data;
			@(posedge clk);
			#1;
			cs   = 1'b0;
			we   = 1'b0;
			be   = 4'h0;
			addr = 32'h0;
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

	task expect_bit;
		input got;
		input exp;
		input [255:0] tag;
		begin
			if (got === exp) begin
				pass_cnt = pass_cnt + 1;
				$display("[PASS] %0s: got=%0d", tag, got);
			end else begin
				fail_cnt = fail_cnt + 1;
				$display("[FAIL] %0s: got=%0d exp=%0d", tag, got, exp);
			end
		end
	endtask

	task send_rx_byte;
		input [7:0] b;
		begin
			uart_rx = 1'b1;
			@(posedge clk);

			// Start bit
			uart_rx = 1'b0;
			for (i = 0; i < BIT_CYCLES; i = i + 1) @(posedge clk);

			// Data bits LSB first
			for (i = 0; i < 8; i = i + 1) begin
				uart_rx = b[i];
				repeat (BIT_CYCLES) @(posedge clk);
			end

			// Stop bit
			uart_rx = 1'b1;
			repeat (BIT_CYCLES) @(posedge clk);
		end
	endtask

	task check_tx_frame;
		input [7:0] b;
		integer k;
		begin
			timeout = 200;
			while ((uart_tx !== 1'b0) && (timeout > 0)) begin
				@(posedge clk);
				timeout = timeout - 1;
			end

			if (timeout == 0) begin
				fail_cnt = fail_cnt + 1;
				$display("[FAIL] TX frame start timeout");
			end else begin
				// Move to center of start bit
				repeat (BIT_CYCLES/2) @(posedge clk);
				expect_bit(uart_tx, 1'b0, "TX start bit");

				// Sample 8 data bits
				for (k = 0; k < 8; k = k + 1) begin
					repeat (BIT_CYCLES) @(posedge clk);
					expect_bit(uart_tx, b[k], "TX data bit");
				end

				// Sample stop bit
				repeat (BIT_CYCLES) @(posedge clk);
				expect_bit(uart_tx, 1'b1, "TX stop bit");
			end
		end
	endtask

	initial begin
		clk  = 1'b0;
		rst_n = 1'b0;
		cs   = 1'b0;
		we   = 1'b0;
		be   = 4'h0;
		addr = 32'h0;
		wdata = 32'h0;
		uart_rx = 1'b1;
		pass_cnt = 0;
		fail_cnt = 0;

		$display("========================================");
		$display("UART Controller Standalone Simulation");
		$display("========================================");

		repeat (5) @(posedge clk);
		rst_n = 1'b1;
		repeat (2) @(posedge clk);

		// STATUS after reset: tx_ready=1, rx_valid=0
		mmio_read(REG_STATUS, rd);
		expect_eq(rd[1:0], 2'b01, "STATUS after reset");

		// Program baud divider to speed up simulation.
		mmio_write(REG_BAUD_DIV, BIT_CYCLES, 4'hF);
		mmio_read(REG_BAUD_DIV, rd);
		expect_eq(rd, BIT_CYCLES, "BAUD_DIV readback");

		// Enable IRQs.
		mmio_write(REG_CTRL, 32'h0000_0003, 4'h1);
		mmio_read(REG_CTRL, rd);
		expect_eq(rd[1:0], 2'b11, "CTRL readback");

		// tx_ready is 1 now, so tx irq should be high when enabled.
		expect_bit(uart_irq, 1'b1, "IRQ on tx_ready");

		// Trigger TX and verify waveform.
		mmio_write(REG_TXDATA, 32'h0000_00A5, 4'h1);
		mmio_read(REG_STATUS, rd);
		expect_bit(rd[0], 1'b0, "STATUS.tx_ready while transmitting");
		check_tx_frame(8'hA5);

		// Wait end of frame and verify ready returns.
		repeat (BIT_CYCLES * 2) @(posedge clk);
		mmio_read(REG_STATUS, rd);
		expect_bit(rd[0], 1'b1, "STATUS.tx_ready after frame");

		// RX path: send one byte and verify RXDATA + rx_valid behavior.
		send_rx_byte(8'h3C);

		timeout = 500;
		rd = 32'h0;
		while ((rd[1] == 1'b0) && (timeout > 0)) begin
			mmio_read(REG_STATUS, rd);
			timeout = timeout - 1;
		end

		if (timeout == 0) begin
			fail_cnt = fail_cnt + 1;
			$display("[FAIL] RX valid timeout");
		end else begin
			pass_cnt = pass_cnt + 1;
			$display("[PASS] RX valid asserted");
		end

		expect_bit(uart_irq, 1'b1, "IRQ on rx_valid");

		mmio_read(REG_RXDATA, rd);
		expect_eq(rd[7:0], 8'h3C, "RXDATA value");

		mmio_read(REG_STATUS, rd);
		expect_bit(rd[1], 1'b0, "STATUS.rx_valid cleared after RXDATA read");

		$display("----------------------------------------");
		$display("PASS = %0d, FAIL = %0d", pass_cnt, fail_cnt);
		$display("----------------------------------------");

		if (fail_cnt == 0) begin
			$display("UART controller test PASSED");
		end else begin
			$display("UART controller test FAILED");
		end

		#20;
		$finish;
	end

endmodule
