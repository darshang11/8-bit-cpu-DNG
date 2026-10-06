//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    10/06/2026
// Design Name:    DNG-8
// Module Name:    memory_tb
// Project Name:   DNG-8: 8-bit multi-cycle von Neumann CPU
// Target Devices: Artix-7 xc7a35tcpg236-1 (Basys 3)
// Tool Versions:  Vivado 2025.2
// Description:    Self-checking testbench for memory. Tests M1 to M10:
//                 startup clear, FF wraparound, write timing, isolation,
//                 data read, write enable, instruction byte order, edge
//                 addresses, independent ports, and shared memory.
//                 Prints each failure, then a PASS/FAIL summary.
//
// Dependencies:   memory.v
//
// Revision:
// Revision 0.01 - Tests M1 to M10, 272 checks
// Additional Comments:
//   Inputs change on falling edges, memory writes on rising edges
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module memory_tb;
    reg clk = 0;
    reg [7:0] i_addr = 0;
    reg [7:0] d_addr = 0;
    reg [7:0] d_data_in = 0;
    reg d_we = 0;
    wire [15:0] i_data;
    wire [7:0] d_data_out;
    integer tests = 0;
    integer errors = 0;
    integer i = 0;

    memory dut(
    .clk(clk), .i_addr(i_addr), .i_data(i_data),
    .d_addr(d_addr), .d_data_out(d_data_out), .d_data_in(d_data_in), .d_we(d_we)
    );

    always #5 clk = ~clk;

    // Write one byte on the next rising edge, then set d_we back to 0.
    task write_mem;
        input [7:0] addr;
        input [7:0] data;
        begin
            @(negedge clk);
            d_addr = addr; d_data_in = data; d_we = 1;
            @(negedge clk);
            d_we = 0;
        end
    endtask

    // Read one byte on the data port, compare against expected; log any mismatch.
    task check_d;
        input [7:0] addr;
        input [7:0] expected;
        begin
            d_addr = addr;
            #1;
            tests = tests + 1;
            if (d_data_out !== expected) begin
                errors = errors + 1;
                $display("FAIL #%0d: data @%h; got %h; want %h", tests, addr, d_data_out, expected);
            end
        end
    endtask

    // Fetch on the instruction port, compare against expected; log any mismatch.
    task check_i;
        input [7:0] addr;
        input [15:0] expected;
        begin
            i_addr = addr;
            #1;
            tests = tests + 1;
            if (i_data !== expected) begin
                errors = errors + 1;
                $display("FAIL #%0d: instr @%h; got %h; want %h", tests, addr, i_data, expected);
            end
        end
    endtask

    // Read both ports at different addresses at once, compare both; log any mismatch.
    task check_both;
        input [7:0] ia, da;
        input [15:0] ei;
        input [7:0] ed;
        begin
            i_addr = ia; d_addr = da;
            #1;
            tests = tests + 1;
            if ((i_data !== ei) || (d_data_out !== ed)) begin
                errors = errors + 1;
                $display("FAIL #%0d: instr @%h = %h, data @%h = %h; want %h, %h",
                tests, ia, i_data, da, d_data_out, ei, ed);
            end
        end
    endtask

    initial begin
        // Let memory's startup loop finish
        @(negedge clk);

        // M1: every box starts at 00
        for (i = 0; i < 256; i = i + 1) begin
            check_d(i, 8'h00);
        end

        // M5, M8: write lands in the right box with all 8 bits, edge addresses
        write_mem(8'h00, 8'hA5);
        write_mem(8'h01, 8'h5A);
        write_mem(8'hFE, 8'hFF);
        write_mem(8'hFF, 8'h80);
        check_d(8'h00, 8'hA5);
        check_d(8'h01, 8'h5A);
        check_d(8'hFE, 8'hFF);
        check_d(8'hFF, 8'h80);

        // M7: instruction is box i_addr (high) then box i_addr + 1 (low)
        check_i(8'h00, 16'hA55A);

        // M2: fetch at FF wraps to box 00
        check_i(8'hFF, 16'h80A5);

        // M4: write to 40 leaves the others alone
        write_mem(8'h40, 8'h3C);
        check_d(8'h40, 8'h3C);
        check_d(8'h3F, 8'h00);
        check_d(8'h41, 8'h00);
        check_d(8'h00, 8'hA5);
        check_d(8'hFF, 8'h80);

        // M3: write shows up after the rising edge, not before
        @(negedge clk);
        d_addr = 8'h50; d_data_in = 8'hC3; d_we = 1;
        check_d(8'h50, 8'h00);
        @(posedge clk);
        #1;
        check_d(8'h50, 8'hC3);
        @(negedge clk);
        d_we = 0;

        // M6: no write when d_we = 0
        @(negedge clk);
        d_addr = 8'h50; d_data_in = 8'hEE; d_we = 0;
        @(negedge clk);
        check_d(8'h50, 8'hC3);

        // M9: both ports read their own address at the same time
        check_both(8'h00, 8'h50, 16'hA55A, 8'hC3);

        // M10: bytes written through the data port show up on the instruction port
        write_mem(8'h30, 8'h99);
        write_mem(8'h31, 8'h11);
        check_i(8'h30, 16'h9911);

        // Summary
        if (errors == 0) $display("All %0d tests passed", tests);
        else             $display("%0d of %0d tests failed", errors, tests);
        $finish;
    end
endmodule
