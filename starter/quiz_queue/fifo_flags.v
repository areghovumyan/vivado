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
    // EMPTY: same slot AND same lap -> all 4 bits equal
    assign empty = (wptr == rptr);
    // FULL: same slot (bits 2..0 equal) but writer is one lap ahead (bit 3 differs)
    assign full  = (wptr[3] != rptr[3]) && (wptr[2:0] == rptr[2:0]);
    // COUNT: 4-bit subtraction wraps around mod 16 by itself
    assign count = wptr - rptr;
endmodule
