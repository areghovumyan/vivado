`timescale 1ns / 1ps
// fifo_sync_tb.v -- the FIFO's corner cases C1..C8, in order.
// Read the FIRST FAIL line first: a later FAIL can be caused by an earlier bug.
module fifo_sync_tb;
    reg        clk, rst, wr_en, rd_en;
    reg  [3:0] din;
    wire [3:0] dout, count;
    wire       full, empty;
    integer errors, i, k;

    fifo_sync dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .din(din),
        .rd_en(rd_en), .dout(dout), .full(full), .empty(empty), .count(count)
    );

    always #5 clk = ~clk;       // 100 MHz

    // push one value: wr_en is 1 for exactly one clock edge
    task push(input [3:0] v);
        begin
            @(negedge clk); din = v; wr_en = 1;
            @(negedge clk); wr_en = 0;
        end
    endtask

    // pop one value: rd_en is 1 for exactly one clock edge
    task pop;
        begin
            @(negedge clk); rd_en = 1;
            @(negedge clk); rd_en = 0;
        end
    endtask

    // check the flags and the count
    task check(input [8*34-1:0] name, input want_empty, input want_full, input [3:0] want_count);
        begin
            $display("%s empty=%b full=%b count=%0d", name, empty, full, count);
            if (empty !== want_empty || full !== want_full || count !== want_count) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("   FAIL %s: expected empty=%b full=%b count=%0d",
                             name, want_empty, want_full, want_count);
            end
        end
    endtask

    // check the value that came out
    task check_out(input [8*34-1:0] name, input [3:0] want);
        begin
            $display("%s dout=%h", name, dout);
            if (dout !== want) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("   FAIL %s: dout=%h, expected %h", name, dout, want);
            end
        end
    endtask

    initial begin
        clk = 0; errors = 0; wr_en = 0; rd_en = 0; din = 0;
        rst = 1; repeat (3) @(negedge clk); rst = 0;

        // C1 -----------------------------------------------------------
        check    ("C1 after reset                    ", 1, 0, 0);
        check_out("C1 after reset                    ", 4'h0);

        // C2 -----------------------------------------------------------
        push(4'h3); check("C2 push 3                         ", 0, 0, 1);
        push(4'h7); check("C2 push 7                         ", 0, 0, 2);
        push(4'hA); check("C2 push A                         ", 0, 0, 3);

        // C3 -----------------------------------------------------------
        pop; check_out("C3 pop: first in comes out first  ", 4'h3);
             check    ("C3 after 1st pop                  ", 0, 0, 2);
        pop; check_out("C3 pop: second comes out second   ", 4'h7);
        pop; check_out("C3 pop: third comes out third     ", 4'hA);
             check    ("C3 after 3 pops (empty again)     ", 1, 0, 0);

        // C4 -----------------------------------------------------------
        pop; check_out("C4 pop when EMPTY: dout unchanged ", 4'hA);
             check    ("C4 pop when EMPTY: still empty    ", 1, 0, 0);

        // C5 -----------------------------------------------------------
        for (i = 1; i <= 8; i = i + 1) push(i);
        check("C5 push 1..8: FULL                ", 0, 1, 8);

        // C6 -----------------------------------------------------------
        push(4'hF);
        check("C6 push F when FULL: ignored      ", 0, 1, 8);
        for (i = 1; i <= 8; i = i + 1) begin
            pop;
            check_out("C6 drain: 1..8 in order, never F  ", i);
        end
        check("C6 drained: empty                 ", 1, 0, 0);

        // C7 -----------------------------------------------------------
        // the pointers go round the 8 slots several times (wrap-around)
        for (k = 0; k < 4; k = k + 1) begin
            for (i = 0; i < 5; i = i + 1) push(k*5 + i);
            check("C7 wrap: 5 pushed                 ", 0, 0, 5);
            for (i = 0; i < 5; i = i + 1) begin
                pop;
                check_out("C7 wrap: order kept               ", k*5 + i);
            end
            check("C7 wrap: empty again              ", 1, 0, 0);
        end
        // push and pop on the SAME clock: one in, one out, count unchanged
        push(4'h1); push(4'h2); push(4'h3);
        @(negedge clk); din = 4'h4; wr_en = 1; rd_en = 1;
        @(negedge clk); wr_en = 0; rd_en = 0;
        check_out("C7 push+pop same clock: oldest out", 4'h1);
        check    ("C7 push+pop same clock: count same", 0, 0, 3);

        // C8 -----------------------------------------------------------
        // serve two more (so the read pointer is NOT at 0), then reset in the middle:
        // BOTH pointers must go back to 0 and the FIFO must be empty
        pop; pop;
        check    ("C8 before reset: 1 left inside    ", 0, 0, 1);
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        check    ("C8 reset in the middle            ", 1, 0, 0);
        check_out("C8 reset in the middle            ", 4'h0);
        push(4'h6); pop;
        check_out("C8 after reset: push 6, pop       ", 4'h6);
        check    ("C8 after reset: push 6, pop       ", 1, 0, 0);

        $display("done: %0d errors", errors);
        $finish;
    end
endmodule
