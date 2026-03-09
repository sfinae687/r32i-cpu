`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for Load/Store Instructions
//////////////////////////////////////////////////////////////////////////////////

module tb_load_store();
    
    reg clk;
    reg rst_n;
    
    // Instruction Memory
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    
    // Data Memory
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
    
    // Data RAM Instance
    dram #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(32)
    ) data_ram (
        .clk(clk),
        .we(dmem_we),
        .byte_we(dmem_be),
        .addr(dmem_addr[9:0]),
        .din(dmem_wdata),
        .dout(dmem_rdata)
    );

    // Instruction ROM model shared with top-level design.
    imem #(
        .ADDR_WIDTH(6),
        .DATA_WIDTH(32)
    ) imem_model (
        .addr(imem_addr[7:2]),
        .dout(imem_rdata)
    );
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Load test program into IMEM.
    initial begin
        imem_model.clear_to_nop();

        // Test SW (Store Word)
        imem_model.write_instr(6'd0, 32'h00100093);  // ADDI x1, x0, 1
        imem_model.write_instr(6'd1, 32'h00200113);  // ADDI x2, x0, 2
        imem_model.write_instr(6'd2, 32'h00202223);  // SW x2, 4(x0)

        // Test LW (Load Word)
        imem_model.write_instr(6'd3, 32'h00402183);  // LW x3, 4(x0)

        // Test SH (Store Halfword)
        imem_model.write_instr(6'd4, 32'h01400213);  // ADDI x4, x0, 20
        imem_model.write_instr(6'd5, 32'h00401423);  // SH x4, 8(x0)

        // Test LH (Load Halfword)
        imem_model.write_instr(6'd6, 32'h00801283);  // LH x5, 8(x0)

        // Test SB (Store Byte)
        imem_model.write_instr(6'd7, 32'hFF700313);  // ADDI x6, x0, -9
        imem_model.write_instr(6'd8, 32'h00600623);  // SB x6, 12(x0)

        // Test LB/LBU
        imem_model.write_instr(6'd9,  32'h00C00383); // LB x7, 12(x0)
        imem_model.write_instr(6'd10, 32'h00C04403); // LBU x8, 12(x0)
    end
    
    // Stimulus
    initial begin
        $display("=== Load/Store Instructions Test ===");
        
        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;
        
        // Run for some cycles
        #200;
        
        // Check Results
        $display("\n=== Register File ===");
        // TODO The test method is error-prone.
        $display("x1 = %h (expected: 0x00000001)", dut.regs.regs[1]);
        $display("x2 = %h (expected: 0x00000002)", dut.regs.regs[2]);
        $display("x3 = %h (expected: 0x00000002)", dut.regs.regs[3]);
        $display("x4 = %h (expected: 0x00000014)", dut.regs.regs[4]);
        $display("x5 = %h (expected: 0x00000014)", dut.regs.regs[5]);
        $display("x6 = %h (expected: 0xFFFFFFF7)", dut.regs.regs[6]);
        $display("x7 = %h (expected: 0xFFFFFFF7)", dut.regs.regs[7]);
        $display("x8 = %h (expected: 0x000000F7)", dut.regs.regs[8]);
        
        $display("\n=== Memory Content ===");
        $display("MEM[4]  = %h (expected: 0x00000002)", 
                 {data_ram.ram3[1], data_ram.ram2[1], data_ram.ram1[1], data_ram.ram0[1]});
        $display("MEM[8]  = %h (expected: 0x????0014)", 
                 {data_ram.ram3[2], data_ram.ram2[2], data_ram.ram1[2], data_ram.ram0[2]});
        $display("MEM[12] = %h (expected: 0x??????F7)", 
                 {data_ram.ram3[3], data_ram.ram2[3], data_ram.ram1[3], data_ram.ram0[3]});
        
        $display("\n=== Test Completed ===");
        $finish;
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0t PC=%h Inst=%h | dmem_addr=%h dmem_we=%b dmem_wdata=%h dmem_rdata=%h", 
                 $time, dut.pc, imem_rdata, dmem_addr, dmem_we, dmem_wdata, dmem_rdata);
    end

endmodule
