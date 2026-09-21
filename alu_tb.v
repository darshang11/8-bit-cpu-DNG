//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    
// Design Name:    
// Module Name:    
// Project Name:   
// Target Devices: 
// Tool Versions: 
// Description: 
//
// Dependencies:   
//
// Revision:
// Revision 0.01 -
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module alu_tb;
    // Signals
    reg [7:0] a;
    reg [7:0] b;
    reg [2:0] op;
    wire [7:0] result;
    wire flag_z;
    wire flag_n;
    wire flag_c;
    integer tests = 0;
    integer errors = 0;
    // Carried over from alu.v for increased readability
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
    // Directed cases
    initial begin
        check(8'h05, 8'h03, ALU_ADD, 8'h08, 1'b0, 1'b0, 1'b0);
        if (errors == 0) $display("All tests passed");
        else $display("%d test(s) failed", errors);
    end
endmodule