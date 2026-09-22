//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    09/20/2026 11:14:18 PM
// Design Name:    DNG-8
// Module Name:    alu
// Project Name:   DNG-8: 8-bit multi-cycle von Neumann CPU
// Target Devices: Artix-7 xc7a35tcpg236-1 (Basys 3)
// Tool Versions:  Vivado 2025.2
// Description:    Combinational 8-bit ALU. Computes into a 9-bit intermediate
//                 so carry/borrow/shifted-out bit lands in bit 8.
//
//                 op   operation   result      carry
//                 000  ADD         a + b       carry out
//                 001  SUB         a - b       borrow (a < b)
//                 010  AND         a & b       0
//                 011  OR          a | b       0
//                 100  XOR         a ^ b       0
//                 101  SHL         a << 1      a[7]
//                 110  SHR         a >> 1      a[0]
//                 111  PASS        a           0
//
//                 Flags: Z = result is zero, N = result[7], C = bit 8.
//
// Dependencies:   None
//
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - All 8 operations and Z/N/C flags implemented
// Revision 0.03 - Passes alu_tb (278 passed tests, 0 failed tests)
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module alu(
    input wire [7:0] a, 
    input wire [7:0] b,
    input wire [2:0] op,
    output [7:0] result,
    output flag_z,
    output flag_n,
    output flag_c
    );
    
    localparam  ALU_ADD = 3'b000,
                ALU_SUB = 3'b001,
                ALU_AND = 3'b010,
                ALU_OR  = 3'b011,
                ALU_XOR = 3'b100,
                ALU_SHL = 3'b101,
                ALU_SHR = 3'b110,
               ALU_PASS = 3'b111;
    
    reg [8:0] wide;  
    always @(*) begin
        wide = 9'd0;
        case (op)
            ALU_ADD: wide = {1'b0, a} + {1'b0, b};
            ALU_SUB: wide = {1'b0, a} - {1'b0, b};
            ALU_AND: wide = {1'b0, a & b};
            ALU_OR : wide = {1'b0, a | b};
            ALU_XOR: wide = {1'b0, a ^ b};
            ALU_SHL: wide = {a, 1'b0};
            ALU_SHR: wide = {a[0], 1'b0, a[7:1]};
            ALU_PASS: wide = {1'b0, a};
            default: wide = 9'd0;
        endcase
    end
    
    assign result = wide [7:0];
    assign flag_c = wide[8];
    assign flag_n = result[7];
    assign flag_z = ~(|result);
    
endmodule
