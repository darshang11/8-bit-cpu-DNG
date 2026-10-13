//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    10/13/2026
// Design Name:    DNG-8
// Module Name:    cpu
// Project Name:   DNG-8: 8-bit multi-cycle von Neumann CPU
// Target Devices: Artix-7 xc7a35tcpg236-1 (Basys 3)
// Tool Versions:  Vivado 2025.2
// Description:    Top level. Connects control, regfile, alu and memory, and
//                 holds PC, IR, A, B, ALUOut and the flags register.
//
//                 Instruction fields:
//                   [15:12] opcode
//                   [11:10] rd (also cond_sel for jumps)
//                   [9:8]   rs
//                   [7:6]   rt
//                   [7:0]   imm / address
//
// Dependencies:   control.v, regfile.v, alu.v, memory.v
//
// Revision:
// Revision 0.01 - File Created, CPU created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module cpu(
    input wire clk,
    input wire rst,
    output wire halted
    );

    localparam  WB_ALU = 2'b00,
                WB_IMM = 2'b01,
                WB_MEM = 2'b10;

    // datapath registers
    reg [7:0]  pc;
    reg [15:0] ir;
    reg [7:0]  a_reg;
    reg [7:0]  b_reg;
    reg [7:0]  alu_out;
    reg        flag_z;
    reg        flag_n;
    reg        flag_c;

    // instruction fields
    wire [3:0] opcode = ir[15:12];
    wire [1:0] rd     = ir[11:10];
    wire [1:0] rs     = ir[9:8];
    wire [1:0] rt     = ir[7:6];
    wire [7:0] imm    = ir[7:0];

    // control signals
    wire       ir_write;
    wire       pc_write;
    wire       pc_src;
    wire       ab_write;
    wire [2:0] alu_op;
    wire       alu_out_write;
    wire       flags_write;
    wire       rf_we;
    wire [1:0] wb_src;
    wire       mem_we;

    // module outputs
    wire [15:0] i_data;
    wire [7:0]  d_data_out;
    wire [7:0]  ra_data;
    wire [7:0]  rb_data;
    wire [7:0]  rc_data;
    wire [7:0]  alu_result;
    wire        alu_z;
    wire        alu_n;
    wire        alu_c;

    // writeback mux
    reg [7:0] wb_data;
    always @(*) begin
        case (wb_src)
            WB_ALU:  wb_data = alu_out;
            WB_IMM:  wb_data = imm;
            WB_MEM:  wb_data = d_data_out;
            default: wb_data = 8'd0;
        endcase
    end

    // PC + 2, or the jump target
    wire [7:0] pc_next = pc_src ? imm : pc + 8'd2;

    always @(posedge clk) begin
        if (rst) begin
            pc      <= 8'd0;
            ir      <= 16'd0;
            a_reg   <= 8'd0;
            b_reg   <= 8'd0;
            alu_out <= 8'd0;
            flag_z  <= 1'b0;
            flag_n  <= 1'b0;
            flag_c  <= 1'b0;
        end
        else begin
            if (pc_write)
                pc <= pc_next;
            if (ir_write)
                ir <= i_data;
            if (ab_write) begin
                a_reg <= ra_data;
                b_reg <= rb_data;
            end
            if (alu_out_write)
                alu_out <= alu_result;
            if (flags_write) begin
                flag_z <= alu_z;
                flag_n <= alu_n;
                flag_c <= alu_c;
            end
        end
    end

    control u_control (
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .cond_sel(rd),
        .flag_z(flag_z),
        .flag_n(flag_n),
        .flag_c(flag_c),
        .ir_write(ir_write),
        .pc_write(pc_write),
        .pc_src(pc_src),
        .ab_write(ab_write),
        .alu_op(alu_op),
        .alu_out_write(alu_out_write),
        .flags_write(flags_write),
        .rf_we(rf_we),
        .wb_src(wb_src),
        .mem_we(mem_we),
        .halted(halted)
    );

    regfile u_regfile (
        .clk(clk),
        .rst(rst),
        .ra_sel(rs),
        .ra_data(ra_data),
        .rb_sel(rt),
        .rb_data(rb_data),
        .rc_sel(rd),
        .rc_data(rc_data),
        .w_sel(rd),
        .w_data(wb_data),
        .we(rf_we)
    );

    alu u_alu (
        .a(a_reg),
        .b(b_reg),
        .op(alu_op),
        .result(alu_result),
        .flag_z(alu_z),
        .flag_n(alu_n),
        .flag_c(alu_c)
    );

    memory u_memory (
        .clk(clk),
        .i_addr(pc),
        .i_data(i_data),
        .d_addr(imm),
        .d_data_out(d_data_out),
        .d_data_in(rc_data),
        .d_we(mem_we)
    );

endmodule