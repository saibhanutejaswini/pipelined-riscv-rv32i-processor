
`timescale 1ns / 1ps

module riscv_processor (
    input logic clk,
    input logic reset
);

    // =========================================================
    // 1. PROGRAM COUNTER AND MEMORIES
    // =========================================================

    logic [31:0] pc;
    logic [31:0] instruction_mem [0:255];
    logic [31:0] data_mem [0:255];
    logic [31:0] registers [0:31];

    logic [31:0] instruction;
    logic [31:0] writeback_data;

    assign instruction = instruction_mem[pc[9:2]];

    // =========================================================
    // 2. IF/ID PIPELINE REGISTER
    // =========================================================

    logic [31:0] if_id_pc;
    logic [31:0] if_id_instr;
    logic if_id_valid;

    // =========================================================
    // 3. INSTRUCTION DECODE
    // =========================================================

    logic [6:0] id_opcode;
    logic [4:0] id_rd;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic [2:0] id_funct3;
    logic [6:0] id_funct7;

    logic [31:0] id_imm;
    logic [31:0] id_read_data1;
    logic [31:0] id_read_data2;

    assign id_opcode = if_id_instr[6:0];
    assign id_rd     = if_id_instr[11:7];
    assign id_funct3 = if_id_instr[14:12];
    assign id_rs1    = if_id_instr[19:15];
    assign id_rs2    = if_id_instr[24:20];
    assign id_funct7 = if_id_instr[31:25];

    // Immediate generation
    always_comb begin
        case (id_opcode)

            // I-type: ADDI, LW
            7'b0010011,
            7'b0000011:
                id_imm = {{20{if_id_instr[31]}},
                          if_id_instr[31:20]};

            // S-type: SW
            7'b0100011:
                id_imm = {{20{if_id_instr[31]}},
                          if_id_instr[31:25],
                          if_id_instr[11:7]};

            // B-type: BEQ, BNE
            7'b1100011:
                id_imm = {{19{if_id_instr[31]}},
                          if_id_instr[31],
                          if_id_instr[7],
                          if_id_instr[30:25],
                          if_id_instr[11:8],
                          1'b0};

            // J-type: JAL
            7'b1101111:
                id_imm = {{11{if_id_instr[31]}},
                          if_id_instr[31],
                          if_id_instr[19:12],
                          if_id_instr[20],
                          if_id_instr[30:21],
                          1'b0};

            default:
                id_imm = 32'd0;

        endcase
    end

    // =========================================================
    // 4. REGISTER FILE WITH WRITEBACK BYPASS
    // =========================================================

    logic mem_wb_valid;
    logic mem_wb_reg_write;
    logic [4:0] mem_wb_rd;
    logic [31:0] mem_wb_result;

    assign writeback_data = mem_wb_result;

    always_comb begin
        id_read_data1 =
            (id_rs1 == 5'd0) ? 32'd0 : registers[id_rs1];

        id_read_data2 =
            (id_rs2 == 5'd0) ? 32'd0 : registers[id_rs2];

        // Bypass the value being written back.
        if (mem_wb_valid && mem_wb_reg_write &&
            (mem_wb_rd != 5'd0) &&
            (mem_wb_rd == id_rs1)) begin
            id_read_data1 = writeback_data;
        end

        if (mem_wb_valid && mem_wb_reg_write &&
            (mem_wb_rd != 5'd0) &&
            (mem_wb_rd == id_rs2)) begin
            id_read_data2 = writeback_data;
        end
    end

    integer reg_index;

    always_ff @(posedge clk) begin
        if (reset) begin
            for (reg_index = 0; reg_index < 32;
                 reg_index = reg_index + 1) begin
                registers[reg_index] <= 32'd0;
            end
        end
        else begin
            registers[0] <= 32'd0;

            if (mem_wb_valid && mem_wb_reg_write &&
                (mem_wb_rd != 5'd0)) begin
                registers[mem_wb_rd] <= mem_wb_result;
            end
        end
    end

    // =========================================================
    // 5. CONTROL UNIT
    // =========================================================

    logic id_reg_write;
    logic id_mem_read;
    logic id_mem_write;
    logic id_mem_to_reg;
    logic id_alu_src;
    logic id_branch;
    logic id_jump;
    logic [3:0] id_alu_control;

    localparam [3:0] ALU_ADD = 4'd0;
    localparam [3:0] ALU_SUB = 4'd1;
    localparam [3:0] ALU_AND = 4'd2;
    localparam [3:0] ALU_OR  = 4'd3;
    localparam [3:0] ALU_XOR = 4'd4;

    always_comb begin
        id_reg_write   = 1'b0;
        id_mem_read    = 1'b0;
        id_mem_write   = 1'b0;
        id_mem_to_reg  = 1'b0;
        id_alu_src     = 1'b0;
        id_branch      = 1'b0;
        id_jump        = 1'b0;
        id_alu_control = ALU_ADD;

        if (if_id_valid) begin
            case (id_opcode)

                // R-type: ADD, SUB, AND, OR, XOR
                7'b0110011: begin
                    id_reg_write = 1'b1;

                    case (id_funct3)
                        3'b000: begin
                            if (id_funct7 == 7'b0100000)
                                id_alu_control = ALU_SUB;
                            else
                                id_alu_control = ALU_ADD;
                        end

                        3'b111: id_alu_control = ALU_AND;
                        3'b110: id_alu_control = ALU_OR;
                        3'b100: id_alu_control = ALU_XOR;

                        default: id_alu_control = ALU_ADD;
                    endcase
                end

                // ADDI
                7'b0010011: begin
                    id_reg_write   = 1'b1;
                    id_alu_src     = 1'b1;
                    id_alu_control = ALU_ADD;
                end

                // LW
                7'b0000011: begin
                    id_reg_write   = 1'b1;
                    id_mem_read    = 1'b1;
                    id_mem_to_reg  = 1'b1;
                    id_alu_src     = 1'b1;
                    id_alu_control = ALU_ADD;
                end

                // SW
                7'b0100011: begin
                    id_mem_write   = 1'b1;
                    id_alu_src     = 1'b1;
                    id_alu_control = ALU_ADD;
                end

                // BEQ, BNE
                7'b1100011: begin
                    id_branch = 1'b1;
                    id_alu_control = ALU_SUB;
                end

                // JAL
                7'b1101111: begin
                    id_reg_write = 1'b1;
                    id_jump      = 1'b1;
                end

                default: begin
                    // Unsupported instruction: no side effects
                end

            endcase
        end
    end

    // =========================================================
    // 6. LOAD-USE HAZARD DETECTION
    // =========================================================

    logic stall;

    logic id_ex_valid;
    logic id_ex_mem_read;
    logic [4:0] id_ex_rd;

    logic id_uses_rs1;
    logic id_uses_rs2;

    always_comb begin
        id_uses_rs1 = 1'b0;
        id_uses_rs2 = 1'b0;

        if (if_id_valid) begin
            case (id_opcode)

                7'b0110011: begin
                    id_uses_rs1 = 1'b1;
                    id_uses_rs2 = 1'b1;
                end

                7'b0010011,
                7'b0000011: begin
                    id_uses_rs1 = 1'b1;
                end

                7'b0100011,
                7'b1100011: begin
                    id_uses_rs1 = 1'b1;
                    id_uses_rs2 = 1'b1;
                end

                default: begin
                    // JAL does not read rs1 or rs2
                end

            endcase
        end
    end

    always_comb begin
        stall = 1'b0;

        if (id_ex_valid && id_ex_mem_read &&
            (id_ex_rd != 5'd0) && if_id_valid) begin

            if ((id_uses_rs1 && (id_rs1 == id_ex_rd)) ||
                (id_uses_rs2 && (id_rs2 == id_ex_rd))) begin
                stall = 1'b1;
            end
        end
    end

    // =========================================================
    // 7. ID/EX PIPELINE REGISTER
    // =========================================================

    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_pc_plus4;
    logic [31:0] id_ex_instr;
    logic [31:0] id_ex_imm;

    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;

    logic [31:0] id_ex_data1;
    logic [31:0] id_ex_data2;

    logic [2:0] id_ex_funct3;

    logic id_ex_reg_write;
    logic id_ex_mem_write;
    logic id_ex_mem_to_reg;
    logic id_ex_alu_src;
    logic id_ex_branch;
    logic id_ex_jump;

    logic [3:0] id_ex_alu_control;

    // =========================================================
    // 8. FORWARDING UNIT
    // =========================================================

    logic ex_mem_valid;
    logic ex_mem_reg_write;
    logic ex_mem_mem_read;
    logic ex_mem_mem_write;
    logic ex_mem_mem_to_reg;
    logic ex_mem_jump;

    logic [4:0] ex_mem_rd;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [31:0] ex_mem_pc_plus4;

    logic [1:0] forward_a;
    logic [1:0] forward_b;

    logic [31:0] forwarded_data1;
    logic [31:0] forwarded_data2;

    always_comb begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // Forward from EX/MEM when the value is available.
        if (ex_mem_valid && ex_mem_reg_write &&
            !ex_mem_mem_read && (ex_mem_rd != 5'd0)) begin

            if (ex_mem_rd == id_ex_rs1)
                forward_a = 2'b10;

            if (ex_mem_rd == id_ex_rs2)
                forward_b = 2'b10;
        end

        // Forward from MEM/WB if a newer EX/MEM match did not win.
        if (mem_wb_valid && mem_wb_reg_write &&
            (mem_wb_rd != 5'd0)) begin

            if ((mem_wb_rd == id_ex_rs1) &&
                (forward_a == 2'b00))
                forward_a = 2'b01;

            if ((mem_wb_rd == id_ex_rs2) &&
                (forward_b == 2'b00))
                forward_b = 2'b01;
        end

        forwarded_data1 = id_ex_data1;
        forwarded_data2 = id_ex_data2;

        case (forward_a)
            2'b10: forwarded_data1 =
                ex_mem_jump ? ex_mem_pc_plus4 : ex_mem_alu_result;
            2'b01: forwarded_data1 = mem_wb_result;
            default: forwarded_data1 = id_ex_data1;
        endcase

        case (forward_b)
            2'b10: forwarded_data2 =
                ex_mem_jump ? ex_mem_pc_plus4 : ex_mem_alu_result;
            2'b01: forwarded_data2 = mem_wb_result;
            default: forwarded_data2 = id_ex_data2;
        endcase
    end

    // =========================================================
    // 9. EXECUTE STAGE ALU
    // =========================================================

    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;

    always_comb begin
        if (id_ex_alu_src)
            alu_operand_b = id_ex_imm;
        else
            alu_operand_b = forwarded_data2;

        case (id_ex_alu_control)

            ALU_ADD: alu_result =
                forwarded_data1 + alu_operand_b;

            ALU_SUB: alu_result =
                forwarded_data1 - alu_operand_b;

            ALU_AND: alu_result =
                forwarded_data1 & alu_operand_b;

            ALU_OR: alu_result =
                forwarded_data1 | alu_operand_b;

            ALU_XOR: alu_result =
                forwarded_data1 ^ alu_operand_b;

            default: alu_result = 32'd0;

        endcase
    end

    // =========================================================
    // 10. BRANCH AND JUMP RESOLUTION
    // =========================================================

    logic branch_taken;
    logic redirect;
    logic [31:0] redirect_target;

    always_comb begin
        branch_taken = 1'b0;
        redirect      = 1'b0;
        redirect_target = 32'd0;

        if (id_ex_valid) begin

            if (id_ex_branch) begin
                case (id_ex_funct3)

                    // BEQ
                    3'b000:
                        branch_taken =
                            (forwarded_data1 == forwarded_data2);

                    // BNE
                    3'b001:
                        branch_taken =
                            (forwarded_data1 != forwarded_data2);

                    default: branch_taken = 1'b0;

                endcase

                if (branch_taken) begin
                    redirect = 1'b1;
                    redirect_target = id_ex_pc + id_ex_imm;
                end
            end

            // JAL
            if (id_ex_jump) begin
                redirect = 1'b1;
                redirect_target = id_ex_pc + id_ex_imm;
            end

        end
    end

    // =========================================================
    // 11. EX/MEM PIPELINE REGISTER
    // =========================================================

    logic [4:0] ex_mem_rd_unused;

    // =========================================================
    // 12. DATA MEMORY AND MEM/WB PIPELINE REGISTER
    // =========================================================

    logic [31:0] mem_wb_pc_plus4;

    // =========================================================
    // 13. PROGRAM COUNTER UPDATE
    // =========================================================

    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= 32'd0;
        end
        else if (redirect) begin
            pc <= redirect_target;
        end
        else if (!stall) begin
            pc <= pc + 32'd4;
        end
    end

    // =========================================================
    // 14. IF/ID REGISTER UPDATE
    // =========================================================

    always_ff @(posedge clk) begin
        if (reset) begin
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'h00000013;
            if_id_valid <= 1'b0;
        end
        else if (redirect) begin
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'h00000013;
            if_id_valid <= 1'b0;
        end
        else if (!stall) begin
            if_id_pc    <= pc;
            if_id_instr <= instruction;
            if_id_valid <= 1'b1;
        end
    end

    // =========================================================
    // 15. ID/EX REGISTER UPDATE
    // =========================================================

    always_ff @(posedge clk) begin
        if (reset || redirect || stall) begin

            id_ex_valid      <= 1'b0;
            id_ex_pc         <= 32'd0;
            id_ex_pc_plus4   <= 32'd0;
            id_ex_instr      <= 32'h00000013;
            id_ex_imm        <= 32'd0;
            id_ex_rs1        <= 5'd0;
            id_ex_rs2        <= 5'd0;
            id_ex_rd         <= 5'd0;
            id_ex_data1      <= 32'd0;
            id_ex_data2      <= 32'd0;
            id_ex_funct3     <= 3'd0;

            id_ex_reg_write  <= 1'b0;
            id_ex_mem_read   <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_alu_src    <= 1'b0;
            id_ex_branch     <= 1'b0;
            id_ex_jump       <= 1'b0;
            id_ex_alu_control <= ALU_ADD;

        end
        else begin

            id_ex_valid      <= if_id_valid;
            id_ex_pc         <= if_id_pc;
            id_ex_pc_plus4   <= if_id_pc + 32'd4;
            id_ex_instr      <= if_id_instr;
            id_ex_imm        <= id_imm;
            id_ex_rs1        <= id_rs1;
            id_ex_rs2        <= id_rs2;
            id_ex_rd         <= id_rd;
            id_ex_data1      <= id_read_data1;
            id_ex_data2      <= id_read_data2;
            id_ex_funct3     <= id_funct3;

            id_ex_reg_write  <= id_reg_write;
            id_ex_mem_read   <= id_mem_read;
            id_ex_mem_write  <= id_mem_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_alu_src    <= id_alu_src;
            id_ex_branch     <= id_branch;
            id_ex_jump       <= id_jump;
            id_ex_alu_control <= id_alu_control;

        end
    end

    // =========================================================
    // 16. EX/MEM REGISTER AND DATA MEMORY ACCESS
    // =========================================================

    always_ff @(posedge clk) begin
        if (reset) begin

            ex_mem_valid       <= 1'b0;
            ex_mem_reg_write   <= 1'b0;
            ex_mem_mem_read    <= 1'b0;
            ex_mem_mem_write   <= 1'b0;
            ex_mem_mem_to_reg  <= 1'b0;
            ex_mem_jump        <= 1'b0;
            ex_mem_rd          <= 5'd0;
            ex_mem_alu_result  <= 32'd0;
            ex_mem_store_data  <= 32'd0;
            ex_mem_pc_plus4    <= 32'd0;

        end
        else begin

            ex_mem_valid       <= id_ex_valid;
            ex_mem_reg_write   <= id_ex_reg_write;
            ex_mem_mem_read    <= id_ex_mem_read;
            ex_mem_mem_write   <= id_ex_mem_write;
            ex_mem_mem_to_reg  <= id_ex_mem_to_reg;
            ex_mem_jump        <= id_ex_jump;
            ex_mem_rd          <= id_ex_rd;
            ex_mem_alu_result  <= id_ex_jump
                                ? id_ex_pc_plus4 : alu_result;
            ex_mem_store_data  <= forwarded_data2;
            ex_mem_pc_plus4    <= id_ex_pc_plus4;

            // Word-addressed data memory.
            if (id_ex_valid && id_ex_mem_write) begin
                data_mem[alu_result[9:2]] <= forwarded_data2;
            end

        end
    end

    // =========================================================
    // 17. MEM/WB REGISTER UPDATE
    // =========================================================

    always_ff @(posedge clk) begin
        if (reset) begin

            mem_wb_valid     <= 1'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_rd        <= 5'd0;
            mem_wb_result    <= 32'd0;
            mem_wb_pc_plus4  <= 32'd0;

        end
        else begin

            mem_wb_valid     <= ex_mem_valid;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_rd        <= ex_mem_rd;
            mem_wb_pc_plus4  <= ex_mem_pc_plus4;

            if (ex_mem_mem_read) begin
                mem_wb_result <= data_mem[ex_mem_alu_result[9:2]];
            end
            else if (ex_mem_jump) begin
                mem_wb_result <= ex_mem_pc_plus4;
            end
            else begin
                mem_wb_result <= ex_mem_alu_result;
            end

        end
    end

endmodule
