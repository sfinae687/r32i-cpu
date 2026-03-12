`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for Fibonacci Sequence Program
// Description: Tests CPU running a Fibonacci program loaded from fib.hex
// 
// Create Date: 2026/03/09 09:15:00
// Module Name: tb_fibnaco
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_fibnaco();
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // Instruction Memory Interface
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    
    // Data Memory Interface
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    
    // CPU Instance
    cpu dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be)
    );
    
    // Data RAM Instance (8KB, 2048 words)
    dram #(
        .ADDR_WIDTH(11),
        .DATA_WIDTH(32)
    ) data_ram (
        .clk(clk),
        .we(dmem_we),
        .byte_we(dmem_be),
        .addr(dmem_addr[10:0]),
        .din(dmem_wdata),
        .dout(dmem_rdata)
    );

    // Instruction Memory Instance - Load from fib.hex
    imem #(
        .ADDR_WIDTH(6),          // 64 words = 256 bytes
        .DATA_WIDTH(32),
        .FILE_INIT("/home/ll06/info/cpu_sources/prog/test/fib/fib.hex")    // Absolute path to Fibonacci program
    ) imem_inst (
        .addr(imem_addr[7:2]),   // Word-aligned address
        .dout(imem_rdata)
    );
    
    // Clock Generation: 100MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Simulation Control
    integer cycle_count;
    integer max_cycles = 500;  // Maximum cycles to prevent infinite loops
    integer i;  // Loop variable
    reg program_terminated;  // Flag to indicate normal termination
    
    // Monitor key registers for Fibonacci results
    wire [31:0] reg_x0  = dut.regs.regs[0];   // Always 0
    wire [31:0] reg_x1  = dut.regs.regs[1];
    wire [31:0] reg_x2  = dut.regs.regs[2];
    wire [31:0] reg_x3  = dut.regs.regs[3];
    wire [31:0] reg_x5  = dut.regs.regs[5];   // Likely Fibonacci term n
    wire [31:0] reg_x6  = dut.regs.regs[6];
    wire [31:0] reg_x7  = dut.regs.regs[7];   // Likely Fibonacci F(n)
    wire [31:0] reg_x28 = dut.regs.regs[28];  // t3
    wire [31:0] reg_x29 = dut.regs.regs[29];  // t4
    wire [31:0] reg_x30 = dut.regs.regs[30];  // t5
    wire [31:0] reg_pc  = dut.pc;
    
    // VCD Dump for waveform analysis
    initial begin
        $dumpfile("tb_fibnaco.vcd");
        $dumpvars(0, tb_fibnaco);
    end
    
    // Test Stimulus and Monitoring
    initial begin
        $display("========================================");
        $display("=== Fibonacci Sequence Test Started ===");
        $display("========================================");
        $display("Loading program from fib.hex...");
        $display("");
        
        // Reset
        rst_n = 0;
        cycle_count = 0;
        program_terminated = 0;
        #20;
        rst_n = 1;
        
        $display("Time(ns) | Cycle | PC       | Instruction | x28(t3)  | x29(t4)  | x30(t5)");
        $display("---------|-------|----------|-------------|----------|----------|----------");
        
        // Run simulation and monitor
        while (cycle_count < max_cycles) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            
            // Display every 10 cycles or when significant events occur
            if ((cycle_count % 10 == 0) || dmem_we) begin
                $display("%8t |  %4d | %08h |    %08h | %08h | %08h | %08h",
                         $time, cycle_count, reg_pc, imem_rdata, 
                         reg_x28, reg_x29, reg_x30);
            end
            
            // Check for ECALL instruction (program termination)
            // ECALL = 0x00000073, EBREAK = 0x00100073
            if (imem_rdata == 32'h00000073 || imem_rdata == 32'h00100073) begin
                $display("");
                $display("========================================");
                $display("=== Program Terminated (ECALL/EBREAK) ===");
                $display("========================================");
                $display("Final cycle count: %d", cycle_count);
                program_terminated = 1;
                cycle_count = max_cycles;  // Exit loop by setting counter to max
            end
        end
        
        if (!program_terminated && cycle_count >= max_cycles) begin
            $display("");
            $display("========================================");
            $display("=== WARNING: Maximum cycles reached ===");
            $display("========================================");
        end
        
        // Display final register state
        $display("");
        $display("Final Register State:");
        $display("--------------------");
        $display("x1  (ra)  = %d (0x%08h)", reg_x1, reg_x1);
        $display("x2  (sp)  = %d (0x%08h)", reg_x2, reg_x2);
        $display("x3  (gp)  = %d (0x%08h)", reg_x3, reg_x3);
        $display("x5  (t0)  = %d (0x%08h)", reg_x5, reg_x5);
        $display("x6  (t1)  = %d (0x%08h)", reg_x6, reg_x6);
        $display("x7  (t2)  = %d (0x%08h)", reg_x7, reg_x7);
        $display("x28 (t3)  = %d (0x%08h)", reg_x28, reg_x28);
        $display("x29 (t4)  = %d (0x%08h)", reg_x29, reg_x29);
        $display("x30 (t5)  = %d (0x%08h)", reg_x30, reg_x30);
        
        // Display some data memory contents
        $display("");
        $display("Data Memory Contents (Fibonacci sequence at 0x100):");
        $display("--------------------------------------");
        $display("Addr  | Index | Value (Decimal)");
        $display("------|-------|----------------");
        // Memory address 0x100-0x13C maps to word index 64-79 (0x100>>2 = 0x40 = 64)
        for (i = 64; i < 80; i = i + 1) begin
            if ({data_ram.ram3[i], data_ram.ram2[i], data_ram.ram1[i], data_ram.ram0[i]} != 32'h0) begin
                $display("0x%03x | F(%2d) | %d", i*4, i-64+1,
                         {data_ram.ram3[i], data_ram.ram2[i], data_ram.ram1[i], data_ram.ram0[i]});
            end
        end
        
        $display("");
        $display("========================================");
        $display("=== Fibonacci Test Completed ===");
        $display("========================================");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #50000;  // 50us timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
