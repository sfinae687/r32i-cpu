`timescale 1ns / 1ps
// =============================================================================
// tb_top.v — Top-level testbench for top_circuit
//
// Generic driver/monitor framework — no specific program is assumed.
// Load any program with +PROG and observe the system through helper tasks.
//
// ---- Always-active monitors ----
//   UART TX monitor  : every byte the CPU sends is printed to the console
//   MMIO trace       : enabled by +TRACE_MMIO (UART write / LED write / BTN read)
//
// ---- Helper tasks (call from $init or interactive use) ----
//   uart_send_rx_byte(byte)              inject one byte into UART RX
//   uart_recv_tx_byte(byte)              capture next byte from UART TX
//   uart_expect_tx_byte(expected)        capture + assert equals expected
//   btn_set_dev(dev, value)              set full 32-bit button word
//   btn_press_bit(dev, bit)              assert one button bit
//   btn_release_bit(dev, bit)            deassert one button bit
//   btn_pulse_bit(dev, bit, cycles)      press, hold N cycles, release
//   btn_clear_all()                      clear all buttons
//   led_read_dev(dev, value)             read current LED word
//   led_wait_mask(dev, mask, exp, max)   poll until (led&mask)==exp
//   led_print_all()                      print all four LED values
//
// ---- Plusargs ----
//   +PROG=<file>      Load IMEM from hex file at simulation start
//   +TIMEOUT=<n>      Stop after N cycles post-reset (default 2 000 000)
//   +NO_TIMEOUT       Run forever — use for non-terminating programs
//   +SCRIPT=<file>    Drive stimulus from a script file (see run_script task)
//   +TRACE_MMIO       Enable MMIO bus event prints
//   +VCD=<file>       Write VCD waveform (default: tb_top.vcd)
//   +NO_VCD           Suppress VCD dump
//
// ---- Build & run (Icarus Verilog) ----
//   cd /home/ll06/info/cpu_sources
//   iverilog -g2005-sv -o simv sim/tb_top.v src/*.v
//   vvp simv +PROG=prog/my_program.hex +NO_TIMEOUT +TRACE_MMIO
// =============================================================================

module tb_top;

    // -------------------------------------------------------------------------
    // Simulation parameters
    // -------------------------------------------------------------------------
    localparam integer CLK_PERIOD    = 10;   // 10 ns -> 100 MHz
    localparam integer BAUD_DIV_SIM  = 16;   // fast baud for simulation
    // 1 bit time in ns
    localparam integer BIT_PERIOD    = CLK_PERIOD * BAUD_DIV_SIM;

    // Address constants (must match runtime.h / top_circuit.v)
    localparam [31:0] UART_BASE  = 32'h1000_0000;
    localparam [31:0] BTN_BASE   = 32'h1000_0100;
    localparam [31:0] LED_BASE   = 32'h1000_0200;
    localparam [31:0] BTN_STRIDE = 32'h10;
    localparam [31:0] LED_STRIDE = 32'h10;
    // UART STATUS register
    localparam [31:0] UART_STATUS = UART_BASE + 32'h08;
    localparam [31:0] UART_BAUD_DIV_REG = UART_BASE + 32'h10;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;

    // UART
    reg         uart_rx_r;         // driven by testbench tasks
    wire        uart_tx;
    wire        uart_irq;

    // Buttons (4 x 32-bit)
    reg  [31:0] btn0, btn1, btn2, btn3;

    // LEDs (4 x 32-bit) — outputs from DUT
    wire [31:0] led0, led1, led2, led3;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    top_circuit dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_rx  (uart_rx_r),
        .uart_tx  (uart_tx),
        .uart_irq (uart_irq),
        .btn0     (btn0),
        .btn1     (btn1),
        .btn2     (btn2),
        .btn3     (btn3),
        .led0     (led0),
        .led1     (led1),
        .led2     (led2),
        .led3     (led3)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // VCD dump
    // -------------------------------------------------------------------------
    reg [1023:0] vcd_file;
    initial begin
        if (!$test$plusargs("NO_VCD")) begin
            if ($value$plusargs("VCD=%s", vcd_file))
                $dumpfile(vcd_file);
            else
                $dumpfile("tb_top.vcd");
            $dumpvars(0, tb_top);
        end
    end

    // -------------------------------------------------------------------------
    // TRACE_MMIO: monitor UART TX writes, LED writes from DUT bus
    // -------------------------------------------------------------------------
    // We watch the internal bus inside dut via hierarchical references.
    // tx write = dut hits UART TXDATA register with a write
    wire trace_uart_tx_wr = dut.hit_uart &&
                            dut.dmem_we  &&
                            (dut.dmem_addr_byte[5:0] == 6'h00);
    wire trace_led_wr0    = dut.led_cs0 && dut.dmem_we;
    wire trace_led_wr1    = dut.led_cs1 && dut.dmem_we;
    wire trace_led_wr2    = dut.led_cs2 && dut.dmem_we;
    wire trace_led_wr3    = dut.led_cs3 && dut.dmem_we;
    wire trace_btn_rd     = dut.btn_cs  && !dut.dmem_we;

    reg trace_mmio;
    initial trace_mmio = $test$plusargs("TRACE_MMIO");

    always @(posedge clk) begin
        if (trace_mmio) begin
            if (trace_uart_tx_wr)
                $display("[TRACE] t=%0t  UART TX write byte=0x%02h  '%c'",
                         $time, dut.dmem_wdata[7:0], dut.dmem_wdata[7:0]);
            if (trace_led_wr0)
                $display("[TRACE] t=%0t  LED0 write addr_off=0x%x wdata=0x%08h",
                         $time, dut.dmem_addr_byte[3:0], dut.dmem_wdata);
            if (trace_led_wr1)
                $display("[TRACE] t=%0t  LED1 write addr_off=0x%x wdata=0x%08h",
                         $time, dut.dmem_addr_byte[3:0], dut.dmem_wdata);
            if (trace_led_wr2)
                $display("[TRACE] t=%0t  LED2 write addr_off=0x%x wdata=0x%08h",
                         $time, dut.dmem_addr_byte[3:0], dut.dmem_wdata);
            if (trace_led_wr3)
                $display("[TRACE] t=%0t  LED3 write addr_off=0x%x wdata=0x%08h",
                         $time, dut.dmem_addr_byte[3:0], dut.dmem_wdata);
            if (trace_btn_rd)
                $display("[TRACE] t=%0t  BTN  read  dev=%0d  rdata=0x%08h",
                         $time, dut.btn_dev_idx, dut.btn_rdata);
        end
    end

    // -------------------------------------------------------------------------
    // UART TX monitor — always active, prints every byte the CPU transmits
    // -------------------------------------------------------------------------
    reg [7:0] uart_mon_byte;
    integer   uart_mon_bit;

    initial begin
        forever begin
            // Wait for start bit (falling edge on uart_tx)
            @(negedge uart_tx);
            // Move to centre of start bit
            #(BIT_PERIOD / 2);
            if (uart_tx !== 1'b0) begin
                $display("[UART TX] WARNING: false start bit at t=%0t", $time);
            end else begin
                uart_mon_byte = 8'h00;
                for (uart_mon_bit = 0; uart_mon_bit < 8; uart_mon_bit = uart_mon_bit + 1) begin
                    #BIT_PERIOD;
                    uart_mon_byte[uart_mon_bit] = uart_tx;
                end
                // Sample stop bit
                #BIT_PERIOD;
                if (uart_tx !== 1'b1)
                    $display("[UART TX] WARNING: bad stop bit at t=%0t", $time);
                // Print printable ASCII inline, otherwise hex
                if (uart_mon_byte >= 8'h20 && uart_mon_byte <= 8'h7e)
                    $write("%c", uart_mon_byte);
                else if (uart_mon_byte == 8'h0a)
                    $write("\n");
                else if (uart_mon_byte == 8'h0d)
                    ; // ignore CR
                else
                    $write("[0x%02h]", uart_mon_byte);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Helper task: tb_reset
    //   Holds reset for 8 cycles, releases, then sets baud divider fast.
    // -------------------------------------------------------------------------
    task tb_reset;
        integer i;
        begin
            rst_n      = 1'b0;
            uart_rx_r  = 1'b1;
            btn0 = 32'h0; btn1 = 32'h0; btn2 = 32'h0; btn3 = 32'h0;
            repeat (8) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            // Give the CPU a few cycles to come out of reset
            repeat (4) @(posedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper task: tb_set_uart_baud_fast
    //   Writes BAUD_DIV_SIM into the UART baud divider register via a
    //   direct force on the internal register (simulation shortcut).
    // -------------------------------------------------------------------------
    task tb_set_uart_baud_fast;
        begin
            // Direct hierarchical force: override reset-default divider
            force dut.uart_inst.baud_div_reg = BAUD_DIV_SIM;
            @(posedge clk);
            release dut.uart_inst.baud_div_reg;
        end
    endtask

    // -------------------------------------------------------------------------
    // UART RX helper: inject one byte into the CPU's UART RX pin
    //   The byte is transmitted LSB-first at BAUD_DIV_SIM * CLK_PERIOD ns/bit.
    // -------------------------------------------------------------------------
    task uart_send_rx_byte;
        input [7:0] b;
        integer k;
        begin
            // Start bit
            uart_rx_r = 1'b0;
            #BIT_PERIOD;
            // 8 data bits, LSB first
            for (k = 0; k < 8; k = k + 1) begin
                uart_rx_r = b[k];
                #BIT_PERIOD;
            end
            // Stop bit
            uart_rx_r = 1'b1;
            #BIT_PERIOD;
        end
    endtask

    // -------------------------------------------------------------------------
    // UART TX helper: receive one byte from uart_tx and return it.
    //   Waits for the start bit, samples 8 data bits.
    // -------------------------------------------------------------------------
    task uart_recv_tx_byte;
        output [7:0] b;
        integer k;
        begin
            // Wait for start bit
            wait (uart_tx === 1'b0);
            #(BIT_PERIOD / 2);
            b = 8'h00;
            for (k = 0; k < 8; k = k + 1) begin
                #BIT_PERIOD;
                b[k] = uart_tx;
            end
            // consume stop bit
            #BIT_PERIOD;
        end
    endtask

    // -------------------------------------------------------------------------
    // UART TX helper: receive byte and assert it equals expected.
    // -------------------------------------------------------------------------
    task uart_expect_tx_byte;
        input [7:0] expected;
        reg   [7:0] got;
        begin
            uart_recv_tx_byte(got);
            if (got !== expected)
                $display("[FAIL] t=%0t  expected 0x%02h ('%c')  got 0x%02h ('%c')",
                         $time, expected, expected, got, got);
        end
    endtask

    // -------------------------------------------------------------------------
    // Button control tasks
    // -------------------------------------------------------------------------

    // Set entire 32-bit word for a button device (dev 0-3)
    task btn_set_dev;
        input integer dev;
        input [31:0]  value;
        begin
            case (dev)
                0: btn0 = value;
                1: btn1 = value;
                2: btn2 = value;
                3: btn3 = value;
            endcase
        end
    endtask

    // Press a single bit within a button device
    task btn_press_bit;
        input integer dev;
        input integer bit_idx;
        begin
            case (dev)
                0: btn0[bit_idx] = 1'b1;
                1: btn1[bit_idx] = 1'b1;
                2: btn2[bit_idx] = 1'b1;
                3: btn3[bit_idx] = 1'b1;
            endcase
        end
    endtask

    // Release a single bit within a button device
    task btn_release_bit;
        input integer dev;
        input integer bit_idx;
        begin
            case (dev)
                0: btn0[bit_idx] = 1'b0;
                1: btn1[bit_idx] = 1'b0;
                2: btn2[bit_idx] = 1'b0;
                3: btn3[bit_idx] = 1'b0;
            endcase
        end
    endtask

    // Clear all buttons
    task btn_clear_all;
        begin
            btn0 = 32'h0; btn1 = 32'h0; btn2 = 32'h0; btn3 = 32'h0;
        end
    endtask

    // Press a bit, hold for hold_cycles clock cycles, then release
    task btn_pulse_bit;
        input integer dev;
        input integer bit_idx;
        input integer hold_cycles;
        begin
            btn_press_bit(dev, bit_idx);
            repeat (hold_cycles) @(posedge clk);
            btn_release_bit(dev, bit_idx);
        end
    endtask

    // -------------------------------------------------------------------------
    // LED read tasks
    // -------------------------------------------------------------------------

    // Read current 32-bit value for an LED device (dev 0-3)
    task led_read_dev;
        input  integer dev;
        output [31:0]  value;
        begin
            case (dev)
                0: value = led0;
                1: value = led1;
                2: value = led2;
                3: value = led3;
                default: value = 32'hx;
            endcase
        end
    endtask

    // Wait until (led[dev] & mask) == expected, or give up after max_cycles.
    // Prints result.
    task led_wait_mask;
        input integer dev;
        input [31:0]  mask;
        input [31:0]  expected;
        input integer max_cycles;
        integer cnt;
        reg [31:0] cur;
        begin
            cnt = 0;
            led_read_dev(dev, cur);
            while ((cur & mask) !== expected && cnt < max_cycles) begin
                @(posedge clk);
                cnt = cnt + 1;
                led_read_dev(dev, cur);
            end
            if ((cur & mask) === expected)
                $display("[LED] dev%0d  mask=0x%08h  matched 0x%08h  (after %0d cycles)",
                         dev, mask, expected, cnt);
            else
                $display("[FAIL] led_wait_mask dev%0d  mask=0x%08h  expected=0x%08h  got=0x%08h  timeout",
                         dev, mask, expected, cur & mask);
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: print current LED state for all 4 devices
    // -------------------------------------------------------------------------
    task led_print_all;
        begin
            $display("[LED] state:  led0=0x%08h  led1=0x%08h  led2=0x%08h  led3=0x%08h",
                     led0, led1, led2, led3);
        end
    endtask

    // =========================================================================
    // Script-file driven stimulus
    //
    // File format — one command per line, # starts a comment:
    //
    //   wait <cycles>
    //   btn_set <dev> <val_hex>       set full 32-bit button word (hex)
    //   btn_press <dev> <bit>
    //   btn_release <dev> <bit>
    //   btn_pulse <dev> <bit> <n>     press, hold N cycles, release
    //   btn_clear
    //   uart_rx <byte_hex>            inject one UART RX byte (hex)
    //   uart_recv                     wait for next UART TX byte and print it
    //   led_print
    //   led_wait <dev> <mask_hex> <expected_hex> <max_cycles>
    //   finish
    // =========================================================================
    task run_script;
        input [1023:0] fname;
        integer        fd;
        integer        r;
        string         line;
        string         cmd;
        integer        a, b, c_int;
        reg [31:0]     val, val2;
        reg [7:0]      rx_byte;
        begin
            fd = $fopen(fname, "r");
            if (fd == 0) begin
                $display("[SCRIPT] ERROR: cannot open '%0s'", fname);
            end else begin
                $display("[SCRIPT] Running '%0s'", fname);
                while (!$feof(fd)) begin
                    line = "";
                    r    = $fgets(line, fd);
                    if (r == 0) begin
                        // EOF or empty read
                    end else begin
                        cmd = "";
                        r   = $sscanf(line, " %s", cmd);
                        if (r < 1) begin
                            // blank line — skip
                        end else if (cmd == "#") begin
                            // comment — skip
                        end else if (cmd == "wait") begin
                            // wait <cycles>
                            a = 0;
                            r = $sscanf(line, " %s %d", cmd, a);
                            if (r == 2) begin
                                $display("[SCRIPT] wait %0d", a);
                                repeat (a) @(posedge clk);
                            end else begin
                                $display("[SCRIPT] WARNING: bad wait syntax: '%0s'", line);
                            end

                        end else if (cmd == "finish") begin
                            // finish
                            $display("[SCRIPT] finish");
                            $fclose(fd);
                            $finish;

                        end else if (cmd == "btn_set") begin
                            // btn_set <dev> <val_hex>
                            a = 0; val = 32'h0;
                            r = $sscanf(line, " %s %d %h", cmd, a, val);
                            if (r == 3) begin
                                $display("[SCRIPT] btn_set dev=%0d val=0x%08h", a, val);
                                btn_set_dev(a, val);
                            end else begin
                                $display("[SCRIPT] WARNING: bad btn_set syntax: '%0s'", line);
                            end

                        end else if (cmd == "btn_press") begin
                            // btn_press <dev> <bit>
                            a = 0; b = 0;
                            r = $sscanf(line, " %s %d %d", cmd, a, b);
                            if (r == 3) begin
                                $display("[SCRIPT] btn_press dev=%0d bit=%0d", a, b);
                                btn_press_bit(a, b);
                            end else begin
                                $display("[SCRIPT] WARNING: bad btn_press syntax: '%0s'", line);
                            end

                        end else if (cmd == "btn_pulse") begin
                            // btn_pulse <dev> <bit> <hold_cycles>
                            a = 0; b = 0; c_int = 1;
                            r = $sscanf(line, " %s %d %d %d", cmd, a, b, c_int);
                            if (r == 4) begin
                                $display("[SCRIPT] btn_pulse dev=%0d bit=%0d hold=%0d", a, b, c_int);
                                btn_pulse_bit(a, b, c_int);
                            end else begin
                                $display("[SCRIPT] WARNING: bad btn_pulse syntax: '%0s'", line);
                            end

                        end else if (cmd == "btn_release") begin
                            // btn_release <dev> <bit>
                            a = 0; b = 0;
                            r = $sscanf(line, " %s %d %d", cmd, a, b);
                            if (r == 3) begin
                                $display("[SCRIPT] btn_release dev=%0d bit=%0d", a, b);
                                btn_release_bit(a, b);
                            end else begin
                                $display("[SCRIPT] WARNING: bad btn_release syntax: '%0s'", line);
                            end

                        end else if (cmd == "btn_clear") begin
                            // btn_clear
                            $display("[SCRIPT] btn_clear");
                            btn_clear_all();

                        end else if (cmd == "uart_rx") begin
                            // uart_rx <byte_hex>
                            val = 32'h0;
                            r = $sscanf(line, " %s %h", cmd, val);
                            if (r == 2) begin
                                $display("[SCRIPT] uart_rx 0x%02h", val[7:0]);
                                uart_send_rx_byte(val[7:0]);
                            end else begin
                                $display("[SCRIPT] WARNING: bad uart_rx syntax: '%0s'", line);
                            end

                        end else if (cmd == "uart_recv") begin
                            // uart_recv
                            $display("[SCRIPT] uart_recv (waiting for TX byte...)");
                            uart_recv_tx_byte(rx_byte);
                            $display("[SCRIPT] uart_recv got: 0x%02h  '%c'", rx_byte, rx_byte);

                        end else if (cmd == "led_print") begin
                            // led_print
                            led_print_all();

                        end else if (cmd == "led_wait") begin
                            // led_wait <dev> <mask_hex> <exp_hex> <max_cycles>
                            a = 0; val = 32'h0; val2 = 32'h0; c_int = 50000;
                            r = $sscanf(line, " %s %d %h %h %d", cmd, a, val, val2, c_int);
                            if (r == 5) begin
                                $display("[SCRIPT] led_wait dev=%0d mask=0x%08h exp=0x%08h max=%0d",
                                         a, val, val2, c_int);
                                led_wait_mask(a, val, val2, c_int);
                            end else begin
                                $display("[SCRIPT] WARNING: bad led_wait syntax: '%0s'", line);
                            end

                        end else begin
                            $display("[SCRIPT] WARNING: unknown command '%0s' (ignored)", cmd);
                        end
                    end
                end // while
                $fclose(fd);
                $display("[SCRIPT] Done.");
            end
        end
    endtask

    // =========================================================================
    // Main control block
    // =========================================================================
    integer       timeout_cycles;
    integer       elapsed;
    reg           no_timeout;
    reg [1023:0]  sim_script;

    initial begin
        // ---- Resolve plusargs ----
        if (!$value$plusargs("TIMEOUT=%d", timeout_cycles))
            timeout_cycles = 2_000_000;
        no_timeout = $test$plusargs("NO_TIMEOUT");

        // ---- Reset + fast baud ----
        tb_reset();
        tb_set_uart_baud_fast();

        $display("[tb_top] Reset released. UART TX monitor active.");
        $display("[tb_top] Use helper tasks to drive buttons / UART RX / observe LEDs.");

        // ---- Optional script file ----
        if ($value$plusargs("SCRIPT=%s", sim_script))
            run_script(sim_script);

        // ---- Timeout / free-run ----
        if (no_timeout) begin
            $display("[tb_top] NO_TIMEOUT set — running forever (Ctrl-C to stop)");
            forever @(posedge clk);
        end else begin
            elapsed = 0;
            while (elapsed < timeout_cycles) begin
                @(posedge clk);
                elapsed = elapsed + 1;
            end
            $display("[tb_top] Reached %0d cycles.", timeout_cycles);
            led_print_all();
        end

        $finish;
    end

endmodule
