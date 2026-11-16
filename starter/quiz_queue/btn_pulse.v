// btn_pulse.v -- one clean 1-clock pulse per button press (Lab 7 + Counters lecture)
//   step 1: two flip-flops bring the button into the clock domain (synchronizer)
//   step 2: the button must stay the same for DB_MAX clocks before we believe it (debounce)
//   step 3: an edge detector turns "button is down" into ONE pulse
module btn_pulse #(
    parameter DB_MAX = 1_000_000        // 1,000,000 clocks = 10 ms at 100 MHz
)(
    input      clk,
    input      btn,                     // raw button pin
    output     pulse                    // 1 for exactly one clock per press
);
    // step 1: synchronizer
    reg [1:0] sync = 2'b00;
    always @(posedge clk)
        sync <= {sync[0], btn};

    // step 2: debounce -- 'stable' only follows the button after DB_MAX quiet clocks
    reg [19:0] cnt      = 20'd0;
    reg        stable   = 1'b0;
    reg        stable_d = 1'b0;         // 'stable' one clock ago
    always @(posedge clk) begin
        if (sync[1] == stable) begin
            cnt <= 20'd0;               // nothing new: keep waiting
        end else if (cnt == DB_MAX-1) begin
            stable <= sync[1];          // it stayed different long enough: believe it
            cnt    <= 20'd0;
        end else begin
            cnt <= cnt + 1'b1;
        end
        stable_d <= stable;
    end

    // step 3: rising edge = it is 1 now, and it was 0 one clock ago
    assign pulse = stable & ~stable_d;   // FIX: rising edge needs NOT stable_d
endmodule
