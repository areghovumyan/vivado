// top_queue.v -- the Order Queue on the Nexys A7-100T
//   SW[3:0] = the order number (one hex digit) to put in line
//   BTNU    = PUSH: put the order at the back of the line
//   BTND    = POP : serve the order at the front; the digit shows it
//   BTNC    = reset: empty the line
//   LED[3:0] = how many orders are waiting (0..8), LED[14] = EMPTY, LED[15] = FULL
module top_queue #(
    parameter DB_MAX = 1_000_000        // 10 ms debounce on the board
)(
    input         CLK100MHZ,            // 100 MHz board clock
    input  [3:0]  SW,                   // order number
    input         BTNU,                 // push
    input         BTND,                 // pop
    input         BTNC,                 // reset
    output [15:0] LED,
    output [6:0]  SEG,                  // {CG,CF,CE,CD,CC,CB,CA}, active low
    output        DP,
    output [7:0]  AN
);
    // ---- reset: two flip-flops (it only needs the level, not an edge)
    reg [1:0] rsync = 2'b00;
    always @(posedge CLK100MHZ)
        rsync <= {rsync[0], BTNC};
    wire rst = rsync[1];

    // ---- one clean pulse per press for push and pop
    wire push, pop;
    btn_pulse #(.DB_MAX(DB_MAX)) u_up (
        .clk(CLK100MHZ), .btn(BTNU), .pulse(push)
    );
    btn_pulse #(.DB_MAX(DB_MAX)) u_dn (
        .clk(CLK100MHZ), .btn(BTND), .pulse(pop)
    );

    // ---- the line itself: an 8-entry FIFO of 4-bit order numbers
    wire [3:0] served;
    wire       full, empty;
    wire [3:0] count;
    fifo_sync u_fifo (
        .clk(CLK100MHZ), .rst(rst),
        .wr_en(push), .din(SW),
        .rd_en(pop),  .dout(served),
        .full(full), .empty(empty), .count(count)
    );

    // ---- the display: the order that was served last
    sseg_hex u_seg (.hex(served), .seg(SEG));

    assign LED = {full, empty, 10'b0, count};   // LED15 = FULL, LED14 = EMPTY
    assign DP  = 1'b1;                          // decimal point OFF
    assign AN  = 8'b1111_1110;                  // only the rightmost digit ON
endmodule
