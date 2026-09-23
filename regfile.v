//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/22/2026 09:56:37 PM
// Design Name: 
// Module Name: regfile
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created; First draft of regfile implemented: four 8-bit registers, 
// three read ports, synchronous write with enable
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module regfile(
    input wire clk,
    input wire rst,
    input wire [1:0] ra_sel,
    output wire [7:0] ra_data,
    input wire [1:0] rb_sel, 
    output wire [7:0] rb_data,
    input wire [1:0] rc_sel,
    output wire [7:0] rc_data,
    input wire [1:0] w_sel,
    input wire [7:0] w_data,
    input wire we
    );
    
    // Create the actual registers
    reg [7:0] r [0:3];
    integer i = 0;
    assign ra_data = r[ra_sel];
    assign rb_data = r[rb_sel];
    assign rc_data = r[rc_sel];   
    
    always @(posedge clk) begin
        if(rst) begin
             for(i = 0; i < 4; i = i + 1) begin
                r[i] <= 8'd0;
             end
        end
        else if (we) begin
            r[w_sel] <= w_data;
        end 
    end
endmodule
