`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Single-cycle RV32I CPU Module
// Description: Implements a single-cycle RISC-V CPU supporting RV32I instructions
//
// Create Date: 2026/03/04 08:37:59
// Last Modified: 2026/03/06
// 
//////////////////////////////////////////////////////////////////////////////////

module cpu(
    // ========== Clock & Reset ==========
    input  wire clk,
    input  wire rst_n,

    // ========== Instruction Memory Interface ==========
    output wire [31:0] imem_addr,      // Instruction address (PC)
    input  wire [31:0] imem_rdata,     // Instruction read data

    // ========== Data Memory Interface ==========
    output wire [31:0] dmem_addr,      // Data address
    output wire [31:0] dmem_wdata,     // Data write
    input  wire [31:0] dmem_rdata,     // Data read
    output wire        dmem_we,        // Write enable
    output wire [3:0]  dmem_be         // Byte enable mask
);

    // ======================== STAGE 1: INSTRUCTION FETCH ========================
    
    reg [31:0] pc;
    wire [31:0] pc_next;           // PC next value (computed later based on instruction type)
    wire [31:0] pc_plus_4 = pc + 32'h4;
    
    assign imem_addr = pc;

    
    // ====================== STAGE 2: INSTRUCTION DECODE ======================
    
    // Instruction fields
    wire [6:0] opcode = imem_rdata[6:0];
    wire [4:0] rd     = imem_rdata[11:7];
    wire [2:0] funct3 = imem_rdata[14:12];
    wire [4:0] rs1    = imem_rdata[19:15];
    wire [4:0] rs2    = imem_rdata[24:20];
    wire [6:0] funct7 = imem_rdata[31:25];
    
    // Instruction type recognition
    wire is_r_type = (opcode == 7'b0110011);  // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
    wire is_i_type = (opcode == 7'b0010011);  // I-type: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU
    wire is_load   = (opcode == 7'b0000011);  // Load:   LB, LH, LW, LBU, LHU
    wire is_store  = (opcode == 7'b0100011);  // Store:  SB, SH, SW
    wire is_branch = (opcode == 7'b1100011);  // Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
    wire is_jal    = (opcode == 7'b1101111);  // JAL:    Jump and Link
    wire is_jalr   = (opcode == 7'b1100111);  // JALR:   Jump and Link Register
    wire is_lui    = (opcode == 7'b0110111);  // LUI:    Load Upper Immediate
    wire is_auipc  = (opcode == 7'b0010111);  // AUIPC:  Add Upper Immediate to PC
    
    // Immediate values (sign-extended)
    wire [31:0] imm_i = {{20{imem_rdata[31]}}, imem_rdata[31:20]};
    wire [31:0] imm_s = {{20{imem_rdata[31]}}, imem_rdata[31:25], imem_rdata[11:7]};
    wire [31:0] imm_b = {{20{imem_rdata[31]}}, imem_rdata[7], imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    wire [31:0] imm_u = {imem_rdata[31:12], 12'h0};
    wire [31:0] imm_j = {{12{imem_rdata[31]}}, imem_rdata[19:12], imem_rdata[20], imem_rdata[30:21], 1'b0};
    
    // ====================== STAGE 3: EXECUTION STAGE ======================
    
    // Register file signals
    wire       reg_wr;
    wire [31:0] reg_wr_data;
    wire [31:0] rs1_data, rs2_data;
    
    // Register file instantiation
    reg_file regs(
        .clk       (clk),
        .we        (reg_wr),
        .w_addr    (rd),
        .w_data    (reg_wr_data),
        .r_addr_a  (rs1),
        .r_data_a  (rs1_data),
        .r_addr_b  (rs2),
        .r_data_b  (rs2_data)
    );
    
    // Branch condition evaluation
    reg branch_taken;
    
    always @(*) begin
        if (is_branch) begin
            case (funct3)
                3'b000: branch_taken = (rs1_data == rs2_data);                        // BEQ
                3'b001: branch_taken = (rs1_data != rs2_data);                        // BNE
                3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));       // BLT
                3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));      // BGE
                3'b110: branch_taken = (rs1_data < rs2_data);                         // BLTU
                3'b111: branch_taken = (rs1_data >= rs2_data);                        // BGEU
                default: branch_taken = 1'b0;
            endcase
        end else begin
            branch_taken = 1'b0;
        end
    end
    
    // PC next value computation
    assign pc_next = (is_jal) ? (pc + imm_j) :
                     (is_jalr) ? ((rs1_data + imm_i) & ~32'h1) :
                     (is_branch && branch_taken) ? (pc + imm_b) :
                     pc_plus_4;
    
    // ALU operand selection
    wire [31:0] alu_operand_a = is_auipc ? pc : rs1_data;
    wire [31:0] alu_operand_b = is_i_type ? imm_i : 
                                is_load   ? imm_i :
                                is_store  ? imm_s :
                                is_auipc  ? imm_u :
                                is_lui    ? 32'h0 :
                                rs2_data;
    
    // ALU signals and control
    wire [31:0] alu_result;
    wire alu_zero, alu_negative, alu_overflow, alu_carry;
    reg  [3:0] alu_ctrl;
    
    alu alu_inst(
        .a            (alu_operand_a),
        .b            (alu_operand_b),
        .alu_control  (alu_ctrl),
        .res          (alu_result),
        .zero         (alu_zero),
        .negative     (alu_negative),
        .overflow     (alu_overflow),
        .carry        (alu_carry)
    );
    
    // ALU control logic
    always @(*) begin
        if (is_r_type || is_i_type) begin
            case (funct3)
                3'b000: begin
                    // ADD (R-type) or ADDI (I-type) or SUB (R-type)
                    if (is_r_type && funct7[5])
                        alu_ctrl = 4'b0110;  // SUB
                    else
                        alu_ctrl = 4'b0010;  // ADD / ADDI
                end
                3'b001: alu_ctrl = 4'b0100;  // SLL / SLLI
                3'b010: alu_ctrl = 4'b0111;  // SLT / SLTI (signed)
                3'b011: alu_ctrl = 4'b1001;  // SLTU / SLTIU (unsigned)
                3'b100: alu_ctrl = 4'b0011;  // XOR / XORI
                3'b101: begin
                    // SRL / SRLI or SRA / SRAI
                    if (is_r_type && funct7[5])
                        alu_ctrl = 4'b1000;  // SRA (arithmetic right shift)
                    else
                        alu_ctrl = 4'b0101;  // SRL / SRLI (logical right shift)
                end
                3'b110: alu_ctrl = 4'b0001;  // OR / ORI
                3'b111: alu_ctrl = 4'b0000;  // AND / ANDI
                default: alu_ctrl = 4'b0010;
            endcase
        end else if (is_load || is_store || is_auipc) begin
            // Load/Store/AUIPC: use ADD for address calculation
            alu_ctrl = 4'b0010;
        end else if (is_lui) begin
            // LUI: pass through operand B (immediate)
            alu_ctrl = 4'b0010;  // ADD with A=0
        end else begin
            alu_ctrl = 4'b0010;  // Default to ADD
        end
    end
    
    // Status register (flags): [N, V, reserved, Z, reserved, H, reserved, C]
    reg [7:0] sreg;
    wire [7:0] sreg_next = {
        alu_negative,           // bit 7: N (Negative)
        alu_overflow,           // bit 6: V (oVerflow)
        1'b0,                   // bit 5: reserved
        alu_zero,               // bit 4: Z (Zero)
        1'b0,                   // bit 3: reserved
        1'b0,                   // bit 2: H (Half-carry, not implemented)
        1'b0,                   // bit 1: reserved
        alu_carry               // bit 0: C (Carry)
    };
    
    // =================== STAGE 4: MEMORY ACCESS STAGE ===================
    
    wire [31:0] mem_addr = alu_result;            // Memory address from ALU
    wire [1:0]  mem_offset = mem_addr[1:0];       // Byte offset within word
    
    // Load data processing (based on funct3)
    reg [31:0] load_data;
    
    always @(*) begin
        case (funct3)
            3'b000: begin  // LB (Load Byte, sign-extended)
                case (mem_offset)
                    2'b00: load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b001: begin  // LH (Load Halfword, sign-extended)
                case (mem_offset[1])
                    1'b0: load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            3'b010: load_data = dmem_rdata;  // LW (Load Word)
            3'b100: begin  // LBU (Load Byte Unsigned, zero-extended)
                case (mem_offset)
                    2'b00: load_data = {24'h0, dmem_rdata[7:0]};
                    2'b01: load_data = {24'h0, dmem_rdata[15:8]};
                    2'b10: load_data = {24'h0, dmem_rdata[23:16]};
                    2'b11: load_data = {24'h0, dmem_rdata[31:24]};
                endcase
            end
            3'b101: begin  // LHU (Load Halfword Unsigned, zero-extended)
                case (mem_offset[1])
                    1'b0: load_data = {16'h0, dmem_rdata[15:0]};
                    1'b1: load_data = {16'h0, dmem_rdata[31:16]};
                endcase
            end
            default: load_data = dmem_rdata;
        endcase
    end
    
    // Store data processing and byte enable generation
    reg [31:0] store_data;
    reg [3:0]  store_byte_enable;
    
    always @(*) begin
        store_data = 32'h0;
        store_byte_enable = 4'b0000;
        
        if (is_store) begin
            case (funct3)
                3'b000: begin  // SB (Store Byte)
                    case (mem_offset)
                        2'b00: begin store_data = {24'h0, rs2_data[7:0]};    store_byte_enable = 4'b0001; end
                        2'b01: begin store_data = {16'h0, rs2_data[7:0], 8'h0};  store_byte_enable = 4'b0010; end
                        2'b10: begin store_data = {8'h0,  rs2_data[7:0], 16'h0}; store_byte_enable = 4'b0100; end
                        2'b11: begin store_data = {rs2_data[7:0], 24'h0};        store_byte_enable = 4'b1000; end
                    endcase
                end
                3'b001: begin  // SH (Store Halfword)
                    case (mem_offset[1])
                        1'b0: begin store_data = {16'h0, rs2_data[15:0]};    store_byte_enable = 4'b0011; end
                        1'b1: begin store_data = {rs2_data[15:0], 16'h0};    store_byte_enable = 4'b1100; end
                    endcase
                end
                3'b010: begin  // SW (Store Word)
                    store_data = rs2_data;
                    store_byte_enable = 4'b1111;
                end
                default: begin
                    store_data = 32'h0;
                    store_byte_enable = 4'b0000;
                end
            endcase
        end
    end
    
    // Data memory interface
    assign dmem_addr  = mem_addr[31:2];      // Word-aligned address (remove low 2 bits)
    assign dmem_wdata = store_data;
    assign dmem_we    = is_store;
    assign dmem_be    = store_byte_enable
    ;
    
    // =================== STAGE 5: WRITE BACK STAGE ===================
    
    // Register write control: write enabled for R/I-type, Load, JAL, JALR, LUI, AUIPC, but not x0
    assign reg_wr      = ((is_r_type || is_i_type || is_load || is_jal || is_jalr || is_lui || is_auipc) && (rd != 5'b0));
    
    // Register write data selection
    assign reg_wr_data = is_load ? load_data :
                         (is_jal || is_jalr) ? pc_plus_4 :
                         is_lui ? imm_u :
                         alu_result;
    
    
    // ==================== SEQUENTIAL LOGIC ====================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset to initial state
            pc   <= 32'h0000_0000;
            sreg <= 8'h00;
        end else begin
            // Update program counter on every clock
            pc <= pc_next;
            
            // Update status flags after R-type and I-type arithmetic/logic operations
            // (Skip flag update for Load/Store instructions, and NOP instructions)
            if (is_r_type || is_i_type) begin
                sreg <= sreg_next;
            end
        end
    end

endmodule
