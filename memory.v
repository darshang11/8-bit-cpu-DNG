`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/06/2026 06:37:59 PM
// Design Name: 
// Module Name: memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module memory(
    input wire clk,
    input wire [7:0] i_addr,
    output wire [15:0] i_data,
    input wire [7:0] d_addr,
    output wire [7:0] d_data_out,
    input wire [7:0] d_data_in,
    input wire d_we
    );
    
    reg [7:0] mem [0:255];
    assign i_data = {mem[i_addr], mem[i_addr + 8'h01]};
    assign d_data_out = mem[d_addr];
    integer i = 0;
    initial begin
        for(i = 0; i < 256; i = i + 1) begin
            mem[i] = 8'd0;
        end
    end
    always @(posedge clk) begin
        if (d_we) begin
            mem[d_addr] <= d_data_in;
        end  
    end
    
endmodule
