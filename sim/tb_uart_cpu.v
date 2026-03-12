`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_uart_cpu
// 
// Description: Tests CPU and UART interaction using hello_uart.s program
//              The CPU sends "Hello, UART!\n" repeatedly through UART MMIO
//
// Test Flow:
//   1. Load hello_uart.hex into instruction memory
//   2. CPU executes program, writes bytes to UART via MMIO
//   3. Monitor UART TX line and decode transmitted characters
//   4. Verify "Hello, UART!\n" string is transmitted correctly
//////////////////////////////////////////////////////////////////////////////////

module tb_uart_cpu;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam integer CLK_PERIOD = 10;  // 100MHz clock (10ns period)
    // Use a small divider to keep simulation runtime short.
    localparam integer BAUD_DIV = 16;
    localparam integer BIT_TIME = CLK_PERIOD * BAUD_DIV;
    
    // Memory map (must match runtime.h and linker.ld)
    localparam [31:0] RAM_BASE  = 32'h0000_0000;
    localparam [31:0] UART_BASE = 32'h1000_0000;
    
    // UART register offsets
    localparam [31:0] UART_TXDATA   = UART_BASE + 32'h00;
    localparam [31:0] UART_RXDATA   = UART_BASE + 32'h04;
    localparam [31:0] UART_STATUS   = UART_BASE + 32'h08;
    localparam [31:0] UART_CTRL     = UART_BASE + 32'h0C;
    localparam [31:0] UART_BAUD_DIV = UART_BASE + 32'h10;

    // =========================================================================
    // Signals
    // =========================================================================
    reg         clk;
    reg         rst_n;
    
    // CPU instruction memory interface
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    
    // CPU data memory interface (DRAM + MMIO)
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_addr_byte;
    
    // UART signals
    wire        uart_rx;
    wire        uart_tx;
    wire        uart_irq;
    
    // Internal MMIO/memory signals
    wire        uart_cs;
    wire [31:0] uart_rdata;
    wire [31:0] mem_rdata;
    wire        hit_imem;
    wire        hit_dram;
    
    // Test control
    integer     i;
    integer     char_count;
    integer     test_cycles;
    integer     uart_tx_write_count;
    integer     verify_fail_count;
    reg [7:0]   received_chars [0:255];
    reg [7:0]   expected_msg [0:13];
    
    // =========================================================================
    // Clock generation: 100MHz (10ns period)
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // =========================================================================
    // DUT Instantiation: CPU
    // =========================================================================
    cpu cpu_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Instruction memory interface
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        
        // Data memory interface (unified for DRAM + MMIO)
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be)
    );
    
    // =========================================================================
    // Memory Controller: wraps IMEM + DRAM
    // =========================================================================
    mem_cont #(
        .IMEM_ADDR_WIDTH (11),
        .DMEM_ADDR_WIDTH (11),
        .DATA_WIDTH      (32),
        .IMEM_FILE_INIT  ("/home/ll06/info/cpu_sources/prog/hello_uart.hex")
    ) mem_inst (
        .clk            (clk),
        .imem_addr      (imem_addr),
        .imem_rdata     (imem_rdata),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_we        (dmem_we),
        .dmem_be        (dmem_be),
        .dmem_rdata     (mem_rdata),
        .dmem_addr_byte (dmem_addr_byte),
        .hit_imem       (hit_imem),
        .hit_dram       (hit_dram)
    );
    
    // =========================================================================
    // UART Controller (MMIO)
    // =========================================================================
    uart_cont #(
        .DEFAULT_BAUD_DIV (BAUD_DIV)
    ) uart_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // MMIO interface
        .cs         (uart_cs),
        .we         (dmem_we),
        .be         (dmem_be),
        .addr       (dmem_addr_byte),
        .wdata      (dmem_wdata),
        .rdata      (uart_rdata),
        
        // UART pins
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .uart_irq   (uart_irq)
    );
    
    // =========================================================================
    // Address Decoder: RAM vs UART
    // =========================================================================
    // dmem_addr_byte is provided by mem_cont.
    assign uart_cs = (dmem_addr_byte >= UART_BASE && dmem_addr_byte < UART_BASE + 32'h100);
    
    // Data read mux
    assign dmem_rdata = uart_cs ? uart_rdata : mem_rdata;
    
    // UART RX tied high (idle state, no input for this test)
    assign uart_rx = 1'b1;
    
    // =========================================================================
    // UART RX Monitor: Decode characters from UART TX line
    // =========================================================================
    task uart_receive_byte;
        output [7:0] rx_byte;
        integer bit_idx;
        begin
            // Wait for start bit (falling edge)
            wait (uart_tx == 1'b0);
            #(BIT_TIME / 2);  // Move to middle of start bit
            
            if (uart_tx !== 1'b0) begin
                $display("ERROR: Invalid start bit at time %t", $time);
                rx_byte = 8'hFF;
            end else begin
                // Sample 8 data bits
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    #BIT_TIME;
                    rx_byte[bit_idx] = uart_tx;
                end
                
                // Check stop bit
                #BIT_TIME;
                if (uart_tx !== 1'b1) begin
                    $display("ERROR: Invalid stop bit at time %t", $time);
                end
            end
        end
    endtask
    
    // =========================================================================
    // Test Stimulus
    // =========================================================================
    initial begin
        // Initialize expected message: "Hello, UART!\n"
        expected_msg[0]  = 8'h48;  // 'H'
        expected_msg[1]  = 8'h65;  // 'e'
        expected_msg[2]  = 8'h6C;  // 'l'
        expected_msg[3]  = 8'h6C;  // 'l'
        expected_msg[4]  = 8'h6F;  // 'o'
        expected_msg[5]  = 8'h2C;  // ','
        expected_msg[6]  = 8'h20;  // ' '
        expected_msg[7]  = 8'h55;  // 'U'
        expected_msg[8]  = 8'h41;  // 'A'
        expected_msg[9]  = 8'h52;  // 'R'
        expected_msg[10] = 8'h54;  // 'T'
        expected_msg[11] = 8'h21;  // '!'
        expected_msg[12] = 8'h0A;  // '\n'
        expected_msg[13] = 8'h00;  // null terminator (not transmitted)
        
        // Initialize signals
        rst_n = 0;
        char_count = 0;
        test_cycles = 0;
        uart_tx_write_count = 0;
        verify_fail_count = 0;
        
        // Open VCD dump
        $dumpfile("tb_uart_cpu.vcd");
        $dumpvars(0, tb_uart_cpu);
        
        // Display test header
        $display("========================================");
        $display("UART + CPU Integration Test");
        $display("Program: hello_uart.s");
        $display("Expected: 'Hello, UART!<newline>'");
        $display("BAUD_DIV=%0d BIT_TIME=%0d ns", BAUD_DIV, BIT_TIME);
        $display("========================================");
        $display("IMEM[0]=0x%08h IMEM[1]=0x%08h IMEM[2]=0x%08h IMEM[3]=0x%08h",
                 mem_inst.imem_inst.mem[0], mem_inst.imem_inst.mem[1],
                 mem_inst.imem_inst.mem[2], mem_inst.imem_inst.mem[3]);
        if ((mem_inst.imem_inst.mem[0] == 32'h00000013) &&
            (mem_inst.imem_inst.mem[1] == 32'h00000013) &&
            (mem_inst.imem_inst.mem[2] == 32'h00000013) &&
            (mem_inst.imem_inst.mem[3] == 32'h00000013)) begin
            $display("[FAIL] IMEM appears to be all NOPs. hello_uart.hex was not loaded.");
            $display("[HINT] In Vivado, add hello_uart.hex to Simulation Sources or use absolute FILE_INIT path.");
            $finish;
        end
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        $display("[%t] Reset released, CPU starting...", $time);
        
        // Receive exactly 13 characters, timeout is handled by a separate monitor.
        while (char_count < 13) begin
            uart_receive_byte(received_chars[char_count]);
            if (received_chars[char_count] >= 32 && received_chars[char_count] < 127)
                $display("[%t] Received char[%0d]: 0x%02h '%c'", 
                         $time, char_count, received_chars[char_count], received_chars[char_count]);
            else
                $display("[%t] Received char[%0d]: 0x%02h '.'", 
                         $time, char_count, received_chars[char_count]);
            char_count = char_count + 1;
        end
        
        // Verify received data
        $display("\n========================================");
        $display("Verification:");
        $display("========================================");
        
        if (char_count == 13) begin
            for (i = 0; i < 13; i = i + 1) begin
                if (received_chars[i] == expected_msg[i]) begin
                    $display("[PASS] Char[%0d]: got=0x%02h exp=0x%02h", 
                             i, received_chars[i], expected_msg[i]);
                end else begin
                    verify_fail_count = verify_fail_count + 1;
                    $display("[FAIL] Char[%0d]: got=0x%02h exp=0x%02h", 
                             i, received_chars[i], expected_msg[i]);
                end
            end

            if (verify_fail_count == 0) begin
                $display("\n[PASS] All 13 characters received correctly!");
                $display("Message: Hello, UART!");
            end else begin
                $display("\n[FAIL] %0d character(s) mismatched.", verify_fail_count);
            end
        end else begin
            $display("[FAIL] Expected 13 characters, got %0d", char_count);
        end
        
        $display("\n========================================");
        $display("Test completed at time %t", $time);
        $display("========================================");
        
        #(CLK_PERIOD * 100);
        $finish;
    end

    // Count CPU writes to UART TX register for quick liveness diagnostics.
    always @(posedge clk) begin
        if (rst_n && dmem_we && uart_cs && (dmem_addr_byte[5:0] == 6'h00)) begin
            uart_tx_write_count <= uart_tx_write_count + 1;
            $display("[%t] CPU->UART TX write #%0d data=0x%02h",
                     $time, uart_tx_write_count + 1, dmem_wdata[7:0]);
        end
    end
    
    // =========================================================================
    // Timeout Monitor
    // =========================================================================
    initial begin
        #(BIT_TIME * 20 * 20);  // Overall test timeout
        $display("\n[TIMEOUT] Test exceeded maximum time limit");
        $display("[DIAG] uart_tx_write_count=%0d, uart_tx=%b", uart_tx_write_count, uart_tx);
        if (uart_tx_write_count == 0) begin
            $display("[DIAG] CPU never wrote UART_TXDATA. Check IMEM loading and compile output.");
        end
        $finish;
    end
    
endmodule
