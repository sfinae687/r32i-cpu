`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Memory Controller (Instruction + Data memories)
//
// Purpose:
// - Provide CPU instruction fetch path from IMEM
// - Provide CPU data access path to DRAM
// - Provide optional data-side read-only IMEM window (for constants in ROM)
//
// Address map (byte address):
// - IMEM: 0x0000_0000 ~ 0x0000_0FFF (read-only, both fetch + data-read window)
// - DRAM: 0x0000_1000 ~ 0x0000_1FFF (read/write)
//////////////////////////////////////////////////////////////////////////////////

module mem_cont #(
    parameter IMEM_ADDR_WIDTH = 10,
    parameter DMEM_ADDR_WIDTH = 10,
    parameter DATA_WIDTH      = 32,
    parameter IMEM_FILE_INIT  = ""
)(
    input  wire                   clk,

    // CPU instruction interface
    input  wire [31:0]            imem_addr,
    output wire [31:0]            imem_rdata,

    // CPU data interface (dmem_addr is word-addressed, same as cpu.v)
    input  wire [31:0]            dmem_addr,
    input  wire [31:0]            dmem_wdata,
    input  wire                   dmem_we,
    input  wire [3:0]             dmem_be,
    output wire [31:0]            dmem_rdata,

    // Optional debug/observe outputs
    output wire [31:0]            dmem_addr_byte,
    output wire                   hit_imem,
    output wire                   hit_dram
);

    localparam [31:0] IMEM_BASE_ADDR = 32'h0000_0000;
    localparam [31:0] IMEM_SIZE_BYTES = 32'h0000_1000;
    localparam [31:0] IMEM_END_ADDR  = IMEM_BASE_ADDR + IMEM_SIZE_BYTES - 1;

    localparam [31:0] DRAM_BASE_ADDR = 32'h0000_1000;
    localparam [31:0] DRAM_SIZE_BYTES = 32'h0000_1000;
    localparam [31:0] DRAM_END_ADDR  = DRAM_BASE_ADDR + DRAM_SIZE_BYTES - 1;

    // CPU dmem_addr is word-addressed; rebuild aligned byte address.
    assign dmem_addr_byte = {dmem_addr, 2'b00};

    assign hit_imem = (dmem_addr_byte >= IMEM_BASE_ADDR) && (dmem_addr_byte <= IMEM_END_ADDR);
    assign hit_dram = (dmem_addr_byte >= DRAM_BASE_ADDR) && (dmem_addr_byte <= DRAM_END_ADDR);

    wire [31:0] imem_d_rdata;
    wire [31:0] dram_rdata;
    wire [31:0] DRAM_BASE_WORD = DRAM_BASE_ADDR[31:2];
    wire [31:0] dmem_dram_word_addr = dmem_addr - DRAM_BASE_WORD;

    // IMEM: fetch port + data-read port
    imem #(
        .ADDR_WIDTH (IMEM_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .FILE_INIT  (IMEM_FILE_INIT)
    ) imem_inst (
        .addr   (imem_addr[IMEM_ADDR_WIDTH+1:2]),
        .dout   (imem_rdata),
        .addr_b (dmem_addr_byte[IMEM_ADDR_WIDTH+1:2]),
        .dout_b (imem_d_rdata)
    );

    // DRAM: write enabled only when address hits DRAM range
    dram #(
        .ADDR_WIDTH (DMEM_ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dram_inst (
        .clk     (clk),
        .we      (dmem_we && hit_dram),
        .byte_we (dmem_be),
        .addr    (dmem_dram_word_addr[DMEM_ADDR_WIDTH-1:0]),
        .din     (dmem_wdata),
        .dout    (dram_rdata)
    );

    // Data read mux
    // IMEM is read-only from data side; stores to IMEM are ignored.
    assign dmem_rdata = hit_dram ? dram_rdata :
                        hit_imem ? imem_d_rdata :
                        32'h0000_0000;

endmodule

