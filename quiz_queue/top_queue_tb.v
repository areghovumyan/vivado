`timescale 1ns / 1ps
// top_queue_tb.v -- tests the whole box: reset, push, pop, full, reset again.
// DB_MAX is shrunk to 4 so a button press takes a few clocks in simulation.
module top_queue_tb;
    reg         clk, btnu, btnd, btnc;
    reg  [3:0]  sw;
    wire [15:0] led;
    wire [6:0]  seg;
    wire        dp;
    wire [7:0]  an;
    integer i, errors;

    top_queue #(.DB_MAX(4)) dut (
        .CLK100MHZ(clk), .SW(sw), .BTNU(btnu), .BTND(btnd), .BTNC(btnc),
        .LED(led), .SEG(seg), .DP(dp), .AN(an)
    );

    always #5 clk = ~clk;       // 100 MHz

    // press a button: hold it 20 clocks, let go for 20 clocks
    task press_up;   begin btnu = 1; repeat (20) @(negedge clk); btnu = 0; repeat (20) @(negedge clk); end endtask
    task press_down; begin btnd = 1; repeat (20) @(negedge clk); btnd = 0; repeat (20) @(negedge clk); end endtask
    task press_c;    begin btnc = 1; repeat (20) @(negedge clk); btnc = 0; repeat (20) @(negedge clk); end endtask

    // one check: compare LEDs and segments with what we expect
    //   LED = {FULL, EMPTY, 10 zeros, COUNT}
    task check(input [15:0] want_led, input [6:0] want_seg, input [8*24-1:0] name);
        begin
            $display("%s LED=%b SEG=%b", name, led, seg);
            if (led !== want_led || seg !== want_seg) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("   FAIL: expected LED=%b SEG=%b", want_led, want_seg);
            end
        end
    endtask

    initial begin
        clk = 0; errors = 0; btnu = 0; btnd = 0; btnc = 0; sw = 4'h0;
        repeat (5) @(negedge clk);

        // T1: reset -> empty line, digit 0
        press_c;
        check(16'b01_0000000000_0000, 7'b1000000, "T1 reset: EMPTY, digit 0");

        // T2, T3: push 3, 7, A (one press = one order)
        sw = 4'h3; press_up;
        check(16'b00_0000000000_0001, 7'b1000000, "T2 push 3: count 1      ");
        sw = 4'h7; press_up;
        sw = 4'hA; press_up;
        check(16'b00_0000000000_0011, 7'b1000000, "T3 push 7, A: count 3   ");

        // T4: serve them in the same order
        press_down;
        check(16'b00_0000000000_0010, 7'b0110000, "T4 pop: digit 3, count 2");
        press_down;
        check(16'b00_0000000000_0001, 7'b1111000, "T4 pop: digit 7, count 1");
        press_down;
        check(16'b01_0000000000_0000, 7'b0001000, "T4 pop: digit A, EMPTY  ");

        // T5: pop on an empty line changes nothing
        press_down;
        check(16'b01_0000000000_0000, 7'b0001000, "T5 pop when EMPTY       ");

        // T6: push 1..8 -> FULL
        for (i = 1; i <= 8; i = i + 1) begin
            sw = i; press_up;
        end
        check(16'b10_0000000000_1000, 7'b0001000, "T6 push 1..8: FULL      ");

        // T7: a 9th push is ignored
        sw = 4'hF; press_up;
        check(16'b10_0000000000_1000, 7'b0001000, "T7 push F when FULL     ");

        // T8: pop -> the FIRST of the eight comes out
        press_down;
        check(16'b00_0000000000_0111, 7'b1111001, "T8 pop: digit 1, count 7");

        // T9: reset in the middle
        press_c;
        check(16'b01_0000000000_0000, 7'b1000000, "T9 reset: EMPTY, digit 0");

        // digit enables and decimal point
        if (an !== 8'b1111_1110 || dp !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: AN=%b DP=%b", an, dp);
        end

        $display("done: %0d errors", errors);
        $finish;
    end
endmodule
