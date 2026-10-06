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
// Description:    Self-checking testbench for regfile. One test per behavior
//                 (B1 to B10): reset, write lands in the right register, all
//                 8 bits stored, no disturbance, write enable, independent
//                 read ports, write timing, and reset beating a write.
//                 Prints each failure, then a PASS/FAIL summary.
//
// Dependencies:   regfile.v
//
// Revision:
// Revision 0.01 - Behaviors B1 to B10, 26 checks
// Additional Comments:
//   The testbench changes inputs only on falling edges; the register file
//   only changes on rising edges, so the two never race. After every step,
//   rst and we go back to 0 (idle) before anything is checked.
//
//   Register state as the tests run:
//     after B1  00 00 00 00
//     after B3  01 02 03 04
//     after B4  A5 5A FF 80
//     after B5  A5 5A 3C 80
//     after B6  A5 5A 3C 80   (no change, that's the point)
//     after B10 C3 5A 3C 80
//     after B2  00 00 00 00
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module regfile_tb;
    // Signals: regs drive the register file's inputs, wires read its outputs
    reg clk = 0;            // must start at 0, or ~X stays X and the clock never runs
    reg rst = 1;            // start in reset
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

    // Device under test
    regfile dut(
        .clk(clk), .rst(rst),
        .ra_sel(ra_sel), .ra_data(ra_data),
        .rb_sel(rb_sel), .rb_data(rb_data),
        .rc_sel(rc_sel), .rc_data(rc_data),
        .w_sel(w_sel), .w_data(w_data), .we(we)
    );

    // Clock: flips every 5 ns, 10 ns period (100 MHz, same as the Basys 3)
    always #5 clk = ~clk;

    // write_reg: store one value into one register.
    // Sets the inputs on a falling edge, lets one rising edge do the write,
    // then turns we back off on the next falling edge.
    task write_reg(input [1:0] sel, input [7:0] data);
        begin
            @(negedge clk);
            w_sel = sel;
            w_data = data;
            we = 1;
            @(negedge clk);
            we = 0;
        end
    endtask

    // check_reg: aim all three read ports at one register and compare.
    // No clock needed, reads are instant (B9). Wait 1 ns for the assigns.
    task check_reg(input [1:0] sel, input [7:0] expected);
        begin
            ra_sel = sel;
            rb_sel = sel;
            rc_sel = sel;
            #1;
            tests = tests + 1;
            if (ra_data !== expected || rb_data !== expected || rc_data !== expected) begin
                errors = errors + 1;
                $display("FAIL t=%0t  R%0d: ra=%h rb=%h rc=%h  expected %h",
                         $time, sel, ra_data, rb_data, rc_data, expected);
            end
        end
    endtask

    // check_ports: aim each port at a different register and compare all three.
    // Only this catches a port wired to the wrong select (B7).
    task check_ports(input [1:0] sa, input [1:0] sb, input [1:0] sc,
                     input [7:0] ea, input [7:0] eb, input [7:0] ec);
        begin
            ra_sel = sa;
            rb_sel = sb;
            rc_sel = sc;
            #1;
            tests = tests + 1;
            if (ra_data !== ea || rb_data !== eb || rc_data !== ec) begin
                errors = errors + 1;
                $display("FAIL t=%0t  ports: ra=R%0d:%h rb=R%0d:%h rc=R%0d:%h  expected %h %h %h",
                         $time, sa, ra_data, sb, rb_data, sc, rc_data, ea, eb, ec);
            end
        end
    endtask

    initial begin
        // ---------------------------------------------------------------
        // B1: reset clears all four registers
        // Fails if: no reset, or the reset loop skips a register
        // Hold rst across two rising edges, release on a falling edge.
        // ---------------------------------------------------------------
        repeat (2) @(negedge clk);
        rst = 0;
        check_reg(0, 8'h00);
        check_reg(1, 8'h00);
        check_reg(2, 8'h00);
        check_reg(3, 8'h00);

        // ---------------------------------------------------------------
        // B3: a write lands in the selected register
        // Fails if: wrong register, half-used or swapped w_sel
        // Small values so a narrow w_data can't trip this test (that's B4).
        // All writes first, then all reads, so a write hitting every
        // register shows up as 04 everywhere.
        // ---------------------------------------------------------------
        write_reg(0, 8'h01);
        write_reg(1, 8'h02);
        write_reg(2, 8'h03);
        write_reg(3, 8'h04);
        check_reg(0, 8'h01);
        check_reg(1, 8'h02);
        check_reg(2, 8'h03);
        check_reg(3, 8'h04);

        // ---------------------------------------------------------------
        // B4: all 8 bits get stored, and old bits are fully replaced
        // Fails if: w_data too narrow, a bit dropped, old value mixed in
        // A5/5A are opposites (every bit seen as 0 and 1), FF is all ones,
        // 80 is bit 7 alone.
        // ---------------------------------------------------------------
        write_reg(0, 8'hA5);
        write_reg(1, 8'h5A);
        write_reg(2, 8'hFF);
        write_reg(3, 8'h80);
        check_reg(0, 8'hA5);
        check_reg(1, 8'h5A);
        check_reg(2, 8'hFF);
        check_reg(3, 8'h80);

        // ---------------------------------------------------------------
        // B5: writing one register doesn't disturb the others
        // Fails if: a write leaks into another register
        // 3C differs from every value already stored, so a leak is visible.
        // ---------------------------------------------------------------
        write_reg(2, 8'h3C);
        check_reg(2, 8'h3C);    // the write worked
        check_reg(0, 8'hA5);    // untouched
        check_reg(1, 8'h5A);    // untouched
        check_reg(3, 8'h80);    // untouched

        // ---------------------------------------------------------------
        // B6: no write when we is low
        // Fails if: we ignored or inverted
        // EE differs from R1's 5A, so a bad write is visible.
        // ---------------------------------------------------------------
        @(negedge clk);
        w_sel = 1;
        w_data = 8'hEE;
        we = 0;
        @(negedge clk);         // one rising edge passes with we low
        check_reg(1, 8'h5A);

        // ---------------------------------------------------------------
        // B7 and B8: three ports read independently
        // Fails if: a port follows another port's select
        // Each port aimed at a different register, then rotated, then
        // two ports on the same register (like ADD R1, R2, R2).
        // ---------------------------------------------------------------
        check_ports(0, 2, 3, 8'hA5, 8'h3C, 8'h80);
        check_ports(3, 0, 1, 8'h80, 8'hA5, 8'h5A);
        check_ports(2, 2, 1, 8'h3C, 8'h3C, 8'h5A);

        // ---------------------------------------------------------------
        // B10: a write is not visible before the rising edge, and is after
        // Fails if: the write isn't clocked, or uses the wrong edge
        // ---------------------------------------------------------------
        @(negedge clk);
        w_sel = 0;
        w_data = 8'hC3;
        we = 1;
        check_reg(0, 8'hA5);    // before the edge: still the old value
        @(posedge clk);
        #1;
        check_reg(0, 8'hC3);    // just after the edge: new value
        @(negedge clk);
        we = 0;

        // ---------------------------------------------------------------
        // B2: reset wins over a write on the same edge (runs last)
        // Fails if: we is checked before rst, or reset can't clear real data
        // R3 after the edge: 00 = pass, 77 = write won, 80 = nothing happened
        // ---------------------------------------------------------------
        @(negedge clk);
        rst = 1;
        we = 1;
        w_sel = 3;
        w_data = 8'h77;
        @(negedge clk);         // exactly one rising edge with both high
        rst = 0;                // both off together, or the next edge
        we = 0;                 // would write 77 into R3
        check_reg(0, 8'h00);
        check_reg(1, 8'h00);
        check_reg(2, 8'h00);
        check_reg(3, 8'h00);

        // Summary
        if (errors == 0)
            $display("PASS: all %0d checks passed", tests);
        else
            $display("FAIL: %0d of %0d checks failed", errors, tests);
        $finish;
    end
endmodule
