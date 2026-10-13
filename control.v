`timescale 1ns / 1ps

module control(
    input wire clk,
    input wire rst,
    input wire [3:0] opcode,     // IR[15:12]
    input wire [1:0] cond_sel,   // IR[11:10], only matters for jumps
    input wire flag_z,          
    input wire flag_n,
    input wire flag_c,
    output reg ir_write,
    output reg pc_write,
    output reg pc_src,           
    output reg ab_write,
    output reg [2:0] alu_op,
    output reg alu_out_write,
    output reg flags_write,
    output reg rf_we,
    output reg [1:0] wb_src,     // 00 = ALUOut, 01 = imm, 10 = memory
    output reg mem_we,
    output reg halted
    );

    localparam  S_FETCH     = 3'd0,
                S_DECODE    = 3'd1,
                S_EXECUTE   = 3'd2,
                S_WRITEBACK = 3'd3,
                S_HALT      = 3'd4;

    localparam  OP_NOP = 4'h0,
                OP_LDI = 4'h1,
                OP_LD  = 4'h2,
                OP_ST  = 4'h3,
                OP_MOV = 4'h4,
                OP_ADD = 4'h5,
                OP_SUB = 4'h6,
                OP_AND = 4'h7,
                OP_OR  = 4'h8,
                OP_XOR = 4'h9,
                OP_SHL = 4'hA,
                OP_SHR = 4'hB,
                OP_CMP = 4'hC,
                OP_JMP = 4'hD,
                OP_JCC = 4'hE,
                OP_HLT = 4'hF;

    // same as alu.v
    localparam  ALU_ADD  = 3'b000,
                ALU_SUB  = 3'b001,
                ALU_AND  = 3'b010,
                ALU_OR   = 3'b011,
                ALU_XOR  = 3'b100,
                ALU_SHL  = 3'b101,
                ALU_SHR  = 3'b110,
                ALU_PASS = 3'b111;

    localparam  WB_ALU = 2'b00,
                WB_IMM = 2'b01,
                WB_MEM = 2'b10;

    reg [2:0] state;
    reg [2:0] next_state;
    reg cond_met;

    always @(posedge clk) begin
        if (rst)
            state <= S_FETCH;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            S_FETCH:     next_state = S_DECODE;
            S_DECODE:    next_state = S_EXECUTE;
            S_EXECUTE:   next_state = S_WRITEBACK;
            S_WRITEBACK: next_state = (opcode == OP_HLT) ? S_HALT : S_FETCH;
            S_HALT:      next_state = S_HALT;
            default:     next_state = S_FETCH;
        endcase
    end

    // jump conditions
    always @(*) begin
        case (cond_sel)
            2'b00:   cond_met = flag_z;    // JZ
            2'b01:   cond_met = ~flag_z;   // JNZ
            2'b10:   cond_met = flag_n;    // JN
            2'b11:   cond_met = flag_c;    // JC
            default: cond_met = 1'b0;
        endcase
    end

    // outputs
    always @(*) begin
        // defaults
        ir_write      = 1'b0;
        pc_write      = 1'b0;
        pc_src        = 1'b0;
        ab_write      = 1'b0;
        alu_op        = ALU_ADD;
        alu_out_write = 1'b0;
        flags_write   = 1'b0;
        rf_we         = 1'b0;
        wb_src        = WB_ALU;
        mem_we        = 1'b0;
        halted        = 1'b0;

        case (state)
            S_FETCH: begin
                ir_write = 1'b1;
                pc_write = 1'b1;          
            end

            S_DECODE: begin
                ab_write = 1'b1;
            end

            S_EXECUTE: begin
                case (opcode)
                    OP_ADD: begin alu_op = ALU_ADD;  alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_SUB: begin alu_op = ALU_SUB;  alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_AND: begin alu_op = ALU_AND;  alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_OR:  begin alu_op = ALU_OR;   alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_XOR: begin alu_op = ALU_XOR;  alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_SHL: begin alu_op = ALU_SHL;  alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_SHR: begin alu_op = ALU_SHR;  alu_out_write = 1'b1; flags_write = 1'b1; end
                    OP_MOV: begin alu_op = ALU_PASS; alu_out_write = 1'b1; end   // no flags
                    OP_CMP: begin alu_op = ALU_SUB;  flags_write = 1'b1;   end   // flags only
                    default: ;   // LDI, LD, ST, NOP, jumps, HLT don't use the ALU
                endcase
            end

            S_WRITEBACK: begin
                case (opcode)
                    OP_MOV, OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_SHL, OP_SHR: begin
                        rf_we  = 1'b1;
                        wb_src = WB_ALU;
                    end
                    OP_LDI: begin rf_we = 1'b1; wb_src = WB_IMM; end
                    OP_LD:  begin rf_we = 1'b1; wb_src = WB_MEM; end
                    OP_ST:  mem_we = 1'b1;
                    OP_JMP: begin pc_src = 1'b1; pc_write = 1'b1;     end
                    OP_JCC: begin pc_src = 1'b1; pc_write = cond_met; end
                    default: ;   // NOP, CMP, HLT don't write
                endcase
            end

            S_HALT: begin
                halted = 1'b1;
            end

            default: ;
        endcase
    end

endmodule