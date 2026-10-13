//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    10/13/2026
// Design Name:    DNG-8
// Module Name:    control_tb
// Project Name:   DNG-8: 8-bit multi-cycle von Neumann CPU
// Target Devices: Artix-7 xc7a35tcpg236-1 (Basys 3)
// Tool Versions:  Vivado 2025.2
// Description:    Self-checking testbench for control.v.
//
//                 The testbench plays the part of the instruction register
//
//                 Checked once per cycle, at the falling edge:
//                   1. every opcode through FETCH, DECODE, EXECUTE, WRITEBACK
//                   2. JZ, JNZ, JN, JC each taken and not taken
//                   3. HLT reaches S_HALT and stays there, IR not reloaded
//                   4. reset held, reset mid-instruction, reset out of halt
//
// Dependencies:   control.v
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module control_tb;

    // same encodings as control.v
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
    // same as ALU.v
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

    localparam  C_JZ  = 2'b00,
                C_JNZ = 2'b01,
                C_JN  = 2'b10,
                C_JC  = 2'b11;


    //                            ir   pc   src  ab    alu_op   out  fl   rf    wb      mem  hlt
    localparam [13:0] E_IDLE   = {1'b0,1'b0,1'b0,1'b0, ALU_ADD, 1'b0,1'b0,1'b0, WB_ALU, 1'b0,1'b0};
    localparam [13:0] E_FETCH  = {1'b1,1'b1,1'b0,1'b0, ALU_ADD, 1'b0,1'b0,1'b0, WB_ALU, 1'b0,1'b0};
    localparam [13:0] E_DECODE = {1'b0,1'b0,1'b0,1'b1, ALU_ADD, 1'b0,1'b0,1'b0, WB_ALU, 1'b0,1'b0};
    localparam [13:0] E_STORE  = {1'b0,1'b0,1'b0,1'b0, ALU_ADD, 1'b0,1'b0,1'b0, WB_ALU, 1'b1,1'b0};
    localparam [13:0] E_HALT   = {1'b0,1'b0,1'b0,1'b0, ALU_ADD, 1'b0,1'b0,1'b0, WB_ALU, 1'b0,1'b1};

    // EXECUTE for an ALU instruction
    function [13:0] exec_alu;
        input [2:0] op;
        input       write_out;
        input       write_flags;
        begin
            exec_alu = {1'b0,1'b0,1'b0,1'b0, op, write_out, write_flags, 1'b0, WB_ALU, 1'b0,1'b0};
        end
    endfunction

    // WRITEBACK into the regfile
    function [13:0] wb_reg;
        input [1:0] src;
        begin
            wb_reg = {1'b0,1'b0,1'b0,1'b0, ALU_ADD, 1'b0,1'b0,1'b1, src, 1'b0,1'b0};
        end
    endfunction

    // WRITEBACK for a jump
    function [13:0] wb_jump;
        input taken;
        begin
            wb_jump = {1'b0, taken, 1'b1, 1'b0, ALU_ADD, 1'b0,1'b0,1'b0, WB_ALU, 1'b0,1'b0};
        end
    endfunction

    // DUT signals
    reg  clk = 1'b0;
    reg  rst = 1'b1;
    reg  [3:0] opcode   = OP_NOP;   
    reg  [1:0] cond_sel = 2'b00;
    reg  flag_z = 1'b0;
    reg  flag_n = 1'b0;
    reg  flag_c = 1'b0;

    wire ir_write, pc_write, pc_src, ab_write;
    wire [2:0] alu_op;
    wire alu_out_write, flags_write, rf_we;
    wire [1:0] wb_src;
    wire mem_we, halted;

    control dut (
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .cond_sel(cond_sel),
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

    always #5 clk = ~clk;   

    // defaults
    reg [3:0] fetch_op   = OP_NOP;
        reg [1:0] fetch_cond = 2'b00;

    always @(posedge clk) begin
        if (ir_write) begin
            opcode   <= fetch_op;
            cond_sel <= fetch_cond;
        end
    end

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    // compare the DUT against one expected vector, report every field that's off
    task check;
        input [2:0]      exp_state;
        input [13:0]     exp;
        input [8*12-1:0] name;
        input [8*10-1:0] phase;
        reg ok;
        begin
            ok = 1'b1;

            if (dut.state !== exp_state) begin
                $display("FAIL %0s %0s: state = %0d, expected %0d", name, phase, dut.state, exp_state);
                ok = 1'b0;
            end

            // write enables
            if (ir_write !== exp[13]) begin
                $display("FAIL %0s %0s: ir_write = %b, expected %b", name, phase, ir_write, exp[13]);
                ok = 1'b0;
            end
            if (pc_write !== exp[12]) begin
                $display("FAIL %0s %0s: pc_write = %b, expected %b", name, phase, pc_write, exp[12]);
                ok = 1'b0;
            end
            if (ab_write !== exp[10]) begin
                $display("FAIL %0s %0s: ab_write = %b, expected %b", name, phase, ab_write, exp[10]);
                ok = 1'b0;
            end
            if (alu_out_write !== exp[6]) begin
                $display("FAIL %0s %0s: alu_out_write = %b, expected %b", name, phase, alu_out_write, exp[6]);
                ok = 1'b0;
            end
            if (flags_write !== exp[5]) begin
                $display("FAIL %0s %0s: flags_write = %b, expected %b", name, phase, flags_write, exp[5]);
                ok = 1'b0;
            end
            if (rf_we !== exp[4]) begin
                $display("FAIL %0s %0s: rf_we = %b, expected %b", name, phase, rf_we, exp[4]);
                ok = 1'b0;
            end
            if (mem_we !== exp[1]) begin
                $display("FAIL %0s %0s: mem_we = %b, expected %b", name, phase, mem_we, exp[1]);
                ok = 1'b0;
            end
            if (halted !== exp[0]) begin
                $display("FAIL %0s %0s: halted = %b, expected %b", name, phase, halted, exp[0]);
                ok = 1'b0;
            end

            // selects, only checked when something actually uses them
            if (exp[12] && (pc_src !== exp[11])) begin
                $display("FAIL %0s %0s: pc_src = %b, expected %b", name, phase, pc_src, exp[11]);
                ok = 1'b0;
            end
            if ((exp[6] || exp[5]) && (alu_op !== exp[9:7])) begin
                $display("FAIL %0s %0s: alu_op = %b, expected %b", name, phase, alu_op, exp[9:7]);
                ok = 1'b0;
            end
            if (exp[4] && (wb_src !== exp[3:2])) begin
                $display("FAIL %0s %0s: wb_src = %b, expected %b", name, phase, wb_src, exp[3:2]);
                ok = 1'b0;
            end

            if (ok)
                pass_count = pass_count + 1;
            else
                fail_count = fail_count + 1;
        end
    endtask

    // run one instruction through all four states.
    // call at a falling edge while the FSM is in FETCH; returns at the falling edge after WRITEBACK
    task run_instr;
        input [3:0]      op;
        input [1:0]      cond;
        input [13:0]     exp_exec;
        input [13:0]     exp_wb;
        input [8*12-1:0] name;
        begin
            fetch_op   = op;     // IR picks this up at the end of FETCH
            fetch_cond = cond;
            check(S_FETCH, E_FETCH, name, "fetch");
            @(negedge clk); check(S_DECODE,    E_DECODE, name, "decode");
            @(negedge clk); check(S_EXECUTE,   exp_exec, name, "execute");
            @(negedge clk); check(S_WRITEBACK, exp_wb,   name, "writeback");
            @(negedge clk);
        end
    endtask

    // set the stored flags for next instruction
    task set_flags;
        input z;
        input n;
        input c;
        begin
            flag_z = z;
            flag_n = n;
            flag_c = c;
        end
    endtask

    initial begin
        rst = 1'b1;
        for (i = 0; i < 3; i = i + 1) begin
            @(negedge clk);
            check(S_FETCH, E_FETCH, "reset", "held");
        end
        rst = 1'b0;


        //        opcode  cond   EXECUTE                         WRITEBACK          name
        run_instr(OP_NOP, 2'b00, E_IDLE,                         E_IDLE,            "NOP");
        run_instr(OP_LDI, 2'b00, E_IDLE,                         wb_reg(WB_IMM),    "LDI");
        run_instr(OP_LD,  2'b00, E_IDLE,                         wb_reg(WB_MEM),    "LD");
        run_instr(OP_ST,  2'b00, E_IDLE,                         E_STORE,           "ST");
        run_instr(OP_MOV, 2'b00, exec_alu(ALU_PASS, 1'b1, 1'b0), wb_reg(WB_ALU),    "MOV");
        run_instr(OP_ADD, 2'b00, exec_alu(ALU_ADD,  1'b1, 1'b1), wb_reg(WB_ALU),    "ADD");
        run_instr(OP_SUB, 2'b00, exec_alu(ALU_SUB,  1'b1, 1'b1), wb_reg(WB_ALU),    "SUB");
        run_instr(OP_AND, 2'b00, exec_alu(ALU_AND,  1'b1, 1'b1), wb_reg(WB_ALU),    "AND");
        run_instr(OP_OR,  2'b00, exec_alu(ALU_OR,   1'b1, 1'b1), wb_reg(WB_ALU),    "OR");
        run_instr(OP_XOR, 2'b00, exec_alu(ALU_XOR,  1'b1, 1'b1), wb_reg(WB_ALU),    "XOR");
        run_instr(OP_SHL, 2'b00, exec_alu(ALU_SHL,  1'b1, 1'b1), wb_reg(WB_ALU),    "SHL");
        run_instr(OP_SHR, 2'b00, exec_alu(ALU_SHR,  1'b1, 1'b1), wb_reg(WB_ALU),    "SHR");
        run_instr(OP_CMP, 2'b00, exec_alu(ALU_SUB,  1'b0, 1'b1), E_IDLE,            "CMP");
        run_instr(OP_JMP, 2'b00, E_IDLE,                         wb_jump(1'b1),     "JMP");

        set_flags(1'b1, 1'b0, 1'b0); run_instr(OP_JCC, C_JZ,  E_IDLE, wb_jump(1'b1), "JZ taken");
        set_flags(1'b0, 1'b0, 1'b0); run_instr(OP_JCC, C_JZ,  E_IDLE, wb_jump(1'b0), "JZ not");
        set_flags(1'b0, 1'b0, 1'b0); run_instr(OP_JCC, C_JNZ, E_IDLE, wb_jump(1'b1), "JNZ taken");
        set_flags(1'b1, 1'b0, 1'b0); run_instr(OP_JCC, C_JNZ, E_IDLE, wb_jump(1'b0), "JNZ not");
        set_flags(1'b0, 1'b1, 1'b0); run_instr(OP_JCC, C_JN,  E_IDLE, wb_jump(1'b1), "JN taken");
        set_flags(1'b0, 1'b0, 1'b0); run_instr(OP_JCC, C_JN,  E_IDLE, wb_jump(1'b0), "JN not");
        set_flags(1'b0, 1'b0, 1'b1); run_instr(OP_JCC, C_JC,  E_IDLE, wb_jump(1'b1), "JC taken");
        set_flags(1'b0, 1'b0, 1'b0); run_instr(OP_JCC, C_JC,  E_IDLE, wb_jump(1'b0), "JC not");

        // reset mid-instruction
        fetch_op   = OP_ADD;
        fetch_cond = 2'b00;
        check(S_FETCH, E_FETCH, "ADD", "fetch");
        @(negedge clk); check(S_DECODE,  E_DECODE, "ADD", "decode");
        @(negedge clk); check(S_EXECUTE, exec_alu(ALU_ADD, 1'b1, 1'b1), "ADD", "execute");
        rst = 1'b1;   // pull reset in the middle of EXECUTE
        @(negedge clk); check(S_FETCH, E_FETCH, "reset", "mid-instr");
        rst = 1'b0;
        run_instr(OP_SUB, 2'b00, exec_alu(ALU_SUB, 1'b1, 1'b1), wb_reg(WB_ALU), "SUB after");

        // halt
        run_instr(OP_HLT, 2'b00, E_IDLE, E_IDLE, "HLT");
        fetch_op = OP_ADD;   // if the IR reloads while halted, it picks this up
        for (i = 0; i < 5; i = i + 1) begin
            check(S_HALT, E_HALT, "HLT", "halted");
            @(negedge clk);
        end
        if (opcode !== OP_HLT) begin
            $display("FAIL HLT halted: IR reloaded while halted (opcode = %h)", opcode);
            fail_count = fail_count + 1;
        end else
            pass_count = pass_count + 1;

        // reset out of halt
        rst = 1'b1;
        @(negedge clk); check(S_FETCH, E_FETCH, "reset", "from halt");
        rst = 1'b0;
        run_instr(OP_LDI, 2'b00, E_IDLE, wb_reg(WB_IMM), "LDI after");


        $display("control_tb: %0d passed, %0d failed", pass_count, fail_count);
        $finish;
    end

endmodule