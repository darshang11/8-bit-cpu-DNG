//////////////////////////////////////////////////////////////////////////////////
// Company:        Independent project
// Engineer:       Darshan Nawin Giriraj
//
// Create Date:    10/06/2026
// Design Name:    DNG-8
// Module Name:    regfile_tb
// Project Name:   DNG-8: 8-bit multi-cycle von Neumann CPU
// Target Devices: Artix-7 xc7a35tcpg236-1 (Basys 3)
// Tool Versions:  Vivado 2025.2
// Description:    Self-checking testbench for regfile. One test per behavior:
//                 reset, write select, 8-bit storage, no disturbance, write
//                 enable, independent read ports, write timing, and reset
//                 priority over a write. Prints each failure, then a
//                 PASS/FAIL summary.
//
// Dependencies:   regfile.v
//
// Revision:
// Revision 0.01 - Tests B1 to B10, 26 checks
// Additional Comments:
//   Inputs change on falling edges, the regfile changes on rising edges
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module regfile_tb;
    reg clk = 0;
    reg rst = 1;
    reg we = 0;
    reg [1:0] ra_sel = 0;
    reg [1:0] rb_sel = 0;
    reg [1:0] rc_sel = 0;
    reg [1:0] w_sel = 0;
    reg [7:0] w_data = 0;
    wire [7:0] ra_data;
    wire [7:0] rb_data;
    wire [7:0] rc_data;
    integer tests = 0;
    integer errors = 0;

    regfile dut(
    .clk(clk), .rst(rst),
    .ra_sel(ra_sel), .ra_data(ra_data),
    .rb_sel(rb_sel), .rb_data(rb_data),
    .rc_sel(rc_sel), .rc_data(rc_data),
    .w_sel(w_sel), .w_data(w_data), .we(we)
    );

    always #5 clk = ~clk;

    // Write one register on the next rising edge, then set we back to 0.
    task write_reg;
        input [1:0] sel;
        input [7:0] data;
        begin
            @(negedge clk);
            w_sel = sel; w_data = data; we = 1;
            @(negedge clk);
            we = 0;
        end
    endtask

    // Read one register on all three ports, compare against expected; log any mismatch.
    task check_reg;
        input [1:0] sel;
        input [7:0] expected;
        begin
            ra_sel = sel; rb_sel = sel; rc_sel = sel;
            #1;
            tests = tests + 1;
            if((ra_data !== expected) || (rb_data !== expected) || (rc_data !== expected)) begin
                errors = errors + 1;
                $display("FAIL #%0d: R%0d; got ra=%h rb=%h rc=%h; want %h",
                tests, sel, ra_data, rb_data, rc_data, expected);
            end
        end
    endtask

    // Read a different register on each port, compare all three; log any mismatch.
    task check_ports;
        input [1:0] sa, sb, sc;
        input [7:0] ea, eb, ec;
        begin
            ra_sel = sa; rb_sel = sb; rc_sel = sc;
            #1;
            tests = tests + 1;
            if((ra_data !== ea) || (rb_data !== eb) || (rc_data !== ec)) begin
                errors = errors + 1;
                $display("FAIL #%0d: R%0d R%0d R%0d; got %h %h %h; want %h %h %h",
                tests, sa, sb, sc, ra_data, rb_data, rc_data, ea, eb, ec);
            end
        end
    endtask

    initial begin
        // B1: reset clears all registers
        repeat (2) @(negedge clk);
        rst = 0;
        check_reg(0, 8'h00);
        check_reg(1, 8'h00);
        check_reg(2, 8'h00);
        check_reg(3, 8'h00);

        // B3: write goes to the selected register
        write_reg(0, 8'h01);
        write_reg(1, 8'h02);
        write_reg(2, 8'h03);
        write_reg(3, 8'h04);
        check_reg(0, 8'h01);
        check_reg(1, 8'h02);
        check_reg(2, 8'h03);
        check_reg(3, 8'h04);

        // B4: all 8 bits stored
        write_reg(0, 8'hA5);
        write_reg(1, 8'h5A);
        write_reg(2, 8'hFF);
        write_reg(3, 8'h80);
        check_reg(0, 8'hA5);
        check_reg(1, 8'h5A);
        check_reg(2, 8'hFF);
        check_reg(3, 8'h80);

        // B5: write to R2 leaves the others alone
        write_reg(2, 8'h3C);
        check_reg(2, 8'h3C);
        check_reg(0, 8'hA5);
        check_reg(1, 8'h5A);
        check_reg(3, 8'h80);

        // B6: no write when we = 0
        @(negedge clk);
        w_sel = 1; w_data = 8'hEE; we = 0;
        @(negedge clk);
        check_reg(1, 8'h5A);

        // B7, B8: ports read independently
        check_ports(0, 2, 3, 8'hA5, 8'h3C, 8'h80);
        check_ports(3, 0, 1, 8'h80, 8'hA5, 8'h5A);
        check_ports(2, 2, 1, 8'h3C, 8'h3C, 8'h5A);

        // B10: write shows up after the rising edge, not before
        @(negedge clk);
        w_sel = 0; w_data = 8'hC3; we = 1;
        check_reg(0, 8'hA5);
        @(posedge clk);
        #1;
        check_reg(0, 8'hC3);
        @(negedge clk);
        we = 0;

        // B2: reset wins over a write on the same edge
        @(negedge clk);
        rst = 1; we = 1; w_sel = 3; w_data = 8'h77;
        @(negedge clk);
        rst = 0; we = 0;
        check_reg(0, 8'h00);
        check_reg(1, 8'h00);
        check_reg(2, 8'h00);
        check_reg(3, 8'h00);

        // Summary
        if (errors == 0) $display("All %0d tests passed", tests);
        else             $display("%0d of %0d tests failed", errors, tests);
        $finish;
    end
endmodule
