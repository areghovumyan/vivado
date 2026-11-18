`timescale 1ns / 1ps
// btn_pulse_tb.v -- one press must give ONE pulse, one clock wide.
// DB_MAX is shrunk to 4 so the debounce takes 4 clocks in simulation.
module btn_pulse_tb;
    reg  clk, btn;
    wire pulse;
    integer errors, pulses, width, max_width, i;

    btn_pulse #(.DB_MAX(4)) dut (.clk(clk), .btn(btn), .pulse(pulse));

    always #5 clk = ~clk;       // 100 MHz

    // count every clock where pulse = 1, and remember the longest run of 1s
    always @(posedge clk) begin
        if (pulse) begin
            pulses = pulses + 1;
            width  = width + 1;
            if (width > max_width) max_width = width;
        end else begin
            width = 0;
        end
    end

    task start_count;
        begin pulses = 0; width = 0; max_width = 0; end
    endtask

    // one check: how many pulses did we see since start_count?
    task check(input integer want, input [8*30-1:0] name);
        begin
            $display("%s pulses=%0d (widest %0d clock)", name, pulses, max_width);
            if (pulses !== want) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("   FAIL %s: got %0d pulses, expected %0d", name, pulses, want);
            end
        end
    endtask

    initial begin
        clk = 0; btn = 0; errors = 0;
        repeat (10) @(negedge clk);

        // B1: nobody touches the button
        start_count;
        repeat (30) @(negedge clk);
        check(0, "B1 button never pressed       ");

        // B2: one clean press, held for 40 clocks
        start_count;
        btn = 1; repeat (40) @(negedge clk);
        check(1, "B2 one press, held 40 clocks  ");

        // B3: letting go must NOT make a pulse
        start_count;
        btn = 0; repeat (40) @(negedge clk);
        check(0, "B3 release the button         ");

        // B4: the pulse is exactly one clock wide
        start_count;
        btn = 1; repeat (40) @(negedge clk);
        btn = 0; repeat (40) @(negedge clk);
        $display("B4 pulse width = %0d clock(s)", max_width);
        if (max_width !== 1) begin
            errors = errors + 1;
            if (errors <= 8)
                $display("   FAIL B4 pulse width: got %0d clocks, expected 1", max_width);
        end

        // B5: a bouncy press (1 0 1 0 1 0) then held down
        start_count;
        for (i = 0; i < 6; i = i + 1) begin
            btn = ~btn; @(negedge clk);
        end
        btn = 1; repeat (40) @(negedge clk);
        check(1, "B5 bouncy press, then held    ");
        btn = 0; repeat (40) @(negedge clk);

        // B6: a 1-clock spike is noise, not a press
        start_count;
        btn = 1; @(negedge clk);
        btn = 0; repeat (30) @(negedge clk);
        check(0, "B6 1-clock spike (noise)      ");

        // B7: two separate presses
        start_count;
        btn = 1; repeat (20) @(negedge clk);
        btn = 0; repeat (20) @(negedge clk);
        btn = 1; repeat (20) @(negedge clk);
        btn = 0; repeat (20) @(negedge clk);
        check(2, "B7 two separate presses       ");

        $display("done: %0d errors", errors);
        $finish;
    end
endmodule
