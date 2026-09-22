//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    09/21/2026
// Design Name:    DNG-8
// Module Name:    alu_tb
// Project Name:   DNG-8: 8-bit multi-cycle von Neumann CPU
// Target Devices: Artix-7 xc7a35tcpg236-1 (Basys 3)
// Tool Versions:  Vivado 2025.2
// Description:    Self-checking testbench for alu. 22 directed cases cover
//                 every operation and drive each flag to both 0 and 1,
//                 followed by an exhaustive ADD sweep (a = 0..255, b = 1).
//                 Prints each failure, then a PASS/FAIL summary.
//
// Dependencies:   alu.v
//
// Revision:
// Revision 0.01 - Check task and 22 directed cases
// Revision 0.02 - ADD sweep (a = 0..255), summary with test count, comments
// Additional Comments:
//   Expected values are worked out by hand
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module alu_tb;
    reg [7:0] a;
    reg [7:0] b;
    reg [2:0] op;
    wire [7:0] result;
    wire flag_z;
    wire flag_n;
    wire flag_c;
    integer tests = 0;
    integer errors = 0;
    integer i = 0;

    // Copied from alu.v for readability
    localparam  ALU_ADD = 3'b000,
                ALU_SUB = 3'b001,
                ALU_AND = 3'b010,
                ALU_OR  = 3'b011,
                ALU_XOR = 3'b100,
                ALU_SHL = 3'b101,
                ALU_SHR = 3'b110,
               ALU_PASS = 3'b111;

    alu dut(
    .a(a), .b(b), .op(op), .result(result), .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c)
    );

    // Apply inputs, let outputs settle, compare all four against expected; log any mismatch.
    task check;
        input [7:0] ta, tb;
        input [2:0] top;
        input [7:0] tresult;
        input tz, tn, tc;
        begin
            a = ta; b = tb; op = top;
            #10;
            tests = tests + 1;
            if((result !== tresult) || (flag_z !== tz) || (flag_n !== tn) || (flag_c !== tc)) begin
                errors = errors + 1;
                $display("FAIL #%0d: op=%b a=%h b=%h; got %h z=%b n=%b c=%b; want %h z=%b n=%b c=%b",
                tests, op, a, b,
                result, flag_z, flag_n, flag_c,
                tresult, tz, tn, tc);
            end
        end
    endtask

    initial begin
        check(8'h05, 8'h03, ALU_ADD,  8'h08, 1'b0, 1'b0, 1'b0);  
        check(8'hFF, 8'h01, ALU_ADD,  8'h00, 1'b1, 1'b0, 1'b1);  
        check(8'h7F, 8'h01, ALU_ADD,  8'h80, 1'b0, 1'b1, 1'b0);  
        check(8'h00, 8'h00, ALU_ADD,  8'h00, 1'b1, 1'b0, 1'b0); 
        check(8'h09, 8'h04, ALU_SUB,  8'h05, 1'b0, 1'b0, 1'b0);  
        check(8'h05, 8'h05, ALU_SUB,  8'h00, 1'b1, 1'b0, 1'b0);  
        check(8'h03, 8'h05, ALU_SUB,  8'hFE, 1'b0, 1'b1, 1'b1);
        check(8'h00, 8'h01, ALU_SUB,  8'hFF, 1'b0, 1'b1, 1'b1);  
        check(8'hF0, 8'h3C, ALU_AND,  8'h30, 1'b0, 1'b0, 1'b0);  
        check(8'hF0, 8'h0F, ALU_AND,  8'h00, 1'b1, 1'b0, 1'b0);  
        check(8'hF0, 8'h0F, ALU_OR,   8'hFF, 1'b0, 1'b1, 1'b0);  
        check(8'hFF, 8'h0F, ALU_XOR,  8'hF0, 1'b0, 1'b1, 1'b0); 
        check(8'hA5, 8'hA5, ALU_XOR,  8'h00, 1'b1, 1'b0, 1'b0);  
        check(8'h01, 8'h00, ALU_SHL,  8'h02, 1'b0, 1'b0, 1'b0);
        check(8'h80, 8'h00, ALU_SHL,  8'h00, 1'b1, 1'b0, 1'b1);  
        check(8'h40, 8'h00, ALU_SHL,  8'h80, 1'b0, 1'b1, 1'b0);  
        check(8'h02, 8'h00, ALU_SHR,  8'h01, 1'b0, 1'b0, 1'b0);  
        check(8'h01, 8'h00, ALU_SHR,  8'h00, 1'b1, 1'b0, 1'b1); 
        check(8'h80, 8'h00, ALU_SHR,  8'h40, 1'b0, 1'b0, 1'b0);  
        check(8'h42, 8'hFF, ALU_PASS, 8'h42, 1'b0, 1'b0, 1'b0); 
        check(8'h00, 8'hFF, ALU_PASS, 8'h00, 1'b1, 1'b0, 1'b0); 
        check(8'h80, 8'h00, ALU_PASS, 8'h80, 1'b0, 1'b1, 1'b0);  

        for (i = 0; i < 256; i = i + 1) begin
            a = i; b = 8'h01; op = ALU_ADD;
            #1;
            tests = tests + 1;
            if (result !== ((i + 1) & 8'hFF)) begin
                errors = errors + 1;
                $display("FAIL sweep: %h + 01 = %h", a, result);
            end
        end

        // Summary
        if (errors == 0) $display("All %0d tests passed", tests);
        else             $display("%0d of %0d tests failed", errors, tests);
        $finish;
    end
endmodule