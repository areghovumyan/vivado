// fifo_sync.v -- the lecture FIFO, made small: 8 entries of 4 bits (FIFO lecture)
//   One clock for both sides. Reset is synchronous, active high.
//   Pointers are 4 bits: 3 address bits + 1 lap bit (that is what tells FULL from EMPTY).
module fifo_sync (
    input            clk,
    input            rst,
    input            wr_en,         // push din on this clock
    input      [3:0] din,
    input            rd_en,         // pop on this clock: dout gets the oldest entry
    output reg [3:0] dout = 4'd0,
    output           full,
    output           empty,
    output     [3:0] count          // 0..8 entries inside
);
    reg [3:0] mem [0:7];            // the 8 storage slots
    reg [3:0] wptr = 4'd0;          // where the next push goes
    reg [3:0] rptr = 4'd0;          // where the next pop comes from

    // the flags come from the two pointers (you write this module)
    fifo_flags u_flags (
        .wptr(wptr), .rptr(rptr),
        .empty(empty), .full(full), .count(count)
    );

    // a push is only a push if there is room; a pop only if there is something
    wire do_wr = wr_en;
    wire do_rd = rd_en & ~empty;

    always @(posedge clk) begin
        if (rst) begin
            wptr <= 4'd0;
            wptr <= 4'd0;
            dout <= 4'd0;
        end else begin
            if (do_wr) begin
                mem[wptr[2:0]] <= din;      // drop the lap bit to pick the slot
                wptr <= wptr + 1'b1;
            end
            if (do_rd) begin
                dout <= mem[rptr[2:0]];
                rptr <= rptr + 1'b1;
            end
        end
    end
endmodule
