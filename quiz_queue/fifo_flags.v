// fifo_flags.v -- EMPTY, FULL and COUNT from the two pointers (FIFO lecture)
//   Each pointer is 4 bits: bit 3 = the lap bit, bits 2..0 = the address (0..7).
//
// *** THIS MODULE IS MISSING. YOU MUST WRITE IT. ***
// The port list below is correct. Do NOT change the port names.
// Write the body between the port list and endmodule (Section 5 tells you what it must do).
module fifo_flags (
    input  [3:0] wptr,
    input  [3:0] rptr,
    output       empty,
    output       full,
    output [3:0] count
);
    // ---- YOUR CODE HERE ----

endmodule
