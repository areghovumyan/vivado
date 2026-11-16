# Design Quiz 2 — Bug Log (page 8) + Study Guide

Line numbers = ORIGINAL starter files (copy kept in `quiz_queue_ORIGINAL/`).

## Bug Log (Section 6)

| # | File : line | What was wrong, and WHY | How found / proof |
|---|---|---|---|
| 1 | `btn_pulse.v : 34` | Was `pulse = stable & stable_d`. That is 1 on **every** clock where the button is down now AND was down one clock ago, so holding the button gives a pulse on every clock (a "level" detector, not an edge detector). A rising edge means "1 now, 0 one clock ago", so the old value must be inverted: `pulse = stable & ~stable_d`. Now the pulse is 1 only on the one clock right after `stable` goes 0→1. | `btn_pulse_tb`: `FAIL B2 one press, held 40 clocks: got 33 pulses, expected 1` (also B4 width 39 clocks). After the fix: `done: 0 errors`. |
| 2 | `fifo_sync.v : 26` | Was `do_wr = wr_en`, so a push was done even when the FIFO was FULL. The 9th push wrote F into slot `wptr[2:0]` = slot 0, overwriting order 1 (the oldest one still waiting), and `wptr` moved on, so count became 9 and FULL went off. The spec says a push when full must be ignored, the same way `do_rd = rd_en & ~empty` ignores a pop when empty. Fix: `do_wr = wr_en & ~full`. | `fifo_sync_tb`: `FAIL C6 push F when FULL: ignored: expected empty=0 full=1 count=8` (got full=0 count=9), then `C6 drain` gave dout=f, expected 1. After the fix, C6 passes. |
| 3 | `fifo_sync.v : 32` | The reset branch had `wptr <= 4'd0;` written twice, and `rptr` was never reset. After a reset in the middle, wptr = 0 but rptr stayed at 2, so count = 0 − 2 = −2 = 14 (4-bit wrap), EMPTY = 0, and the next pop read an old slot. A reset must put BOTH pointers back at 0 so they are equal (empty). Fix: line 32 → `rptr <= 4'd0;`. It is hidden at power-up because both regs start at 0 from their initial values. | `fifo_sync_tb`: `FAIL C8 reset in the middle: expected empty=1 full=0 count=0` (got count=14). `top_queue_tb`: `T9 reset: EMPTY, digit 0 LED=0000000000001100` / `FAIL: expected LED=0100000000000000`. After the fix, all 3 TBs print `done: 0 errors`. |
| 4 | `top_queue.xdc : 9–10` | BTNU was on pin P18 and BTND on M18. In the Digilent Nexys A7-100T master XDC, M18 is BTNU (top) and P18 is BTND (bottom), so the two buttons were swapped. The testbenches drive the ports by name and never see pins, so every simulation passed. Fix: BTNU = M18, BTND = P18. | Board-only bug. Section 3 row 2 would fail: SW=3, press BTNU (top). The top button really drives the pop logic, so on an empty line nothing happens: LD3..0 stays 0000 and LD14 stays ON. Pressing BTND would push instead. After the fix, rows 1–13 all match. |
| fifo_flags | `fifo_flags.v` | `empty = (wptr == rptr)`, `full = (wptr[3] != rptr[3]) && (wptr[2:0] == rptr[2:0])`, `count = wptr - rptr`. Why FULL needs bit 3: with only the 3 address bits, the pointers are equal both when the line is empty and when it is full (the writer went all the way round and caught up with the reader). The lap bit tells the two cases apart: same lap = EMPTY, writer one lap ahead = FULL. Examples with the same bits 2..0: **FULL** wptr = 1_000, rptr = 0_000. **EMPTY** wptr = 0_000, rptr = 0_000. | `fifo_sync_tb` C1 (`empty=1 full=0 count=0`) and C5 (`empty=0 full=1 count=8`) pass. |

## Things checked and NOT broken (do not "fix" them, −3 each)
- `sseg_hex.v`: all 16 patterns are correct (active low, gfedcba).
- `top_queue.v`: the rsync wiring, LED concatenation, AN, DP, and DB_MAX are all fine.
- XDC: the clock, switch, LED, SEG, DP and AN pins all match the master XDC.
- `btn_pulse` counter: 20 bits holds up to 1,048,575, which is more than DB_MAX−1 = 999,999.

## Likely professor questions — short answers
1. **Why two flip-flops on the button?** The button is asynchronous to the clock. A flip-flop that samples it during a change can go metastable. The 2nd FF gives it one full clock to settle, so the rest of the logic sees a clean 0/1.
2. **Why debounce?** A mechanical button bounces for a few ms. Without the debounce, one press looks like several presses, which means several pushes. DB_MAX = 1,000,000 clocks = 10 ms at 100 MHz. The TB uses 4 so the simulation stays short.
3. **Why an edge detector?** A press lasts millions of clocks. We want exactly one push per press, so we keep only the clock where stable = 1 and stable_d = 0.
4. **Why doesn't reset go through btn_pulse?** Reset only needs the level ("hold = stay reset"). It does not matter if it bounces, because resetting twice gives the same result. It still needs the 2-FF synchronizer.
5. **Why is count 4 bits?** The FIFO can hold 0..8 orders. That is 9 values, and 3 bits only go to 7.
6. **Why does `wptr - rptr` work after wrap?** The subtraction is mod 16. For example, 0_010 − 1_110 = 2 − 14 = −12 ≡ 4. Because the pointers are 4 bits (2× the depth), the difference is always the true count 0..8.
7. **Why `mem[wptr[2:0]]`?** There are only 8 slots, so the address is bits 2..0. Bit 3 is just the lap marker.
8. **Why did the simulation pass with the XDC bug?** The testbenches connect to port names. Pin numbers only matter on the real chip.
9. **What would make a latch?** A combinational `always @(*)` where some output is not assigned on some path (an `if` with no `else`, or a `case` with no `default`). Using `assign` avoids latches completely.
10. **Why is bug 3 invisible after power-up?** `rptr` has the initial value 0 in its declaration, so the first reset looks fine. It only shows after pops, when rptr ≠ 0 and you then reset.
11. **What does dout do on a pop when empty?** `do_rd = 0`, so dout keeps its value and the digit still shows the last order served (row 8).
12. **Push and pop on the same clock?** Both happen: one in, one out, and the count does not change (C7).
13. **Active low:** SEG 0 = segment ON. AN = 1111_1110 turns on only digit 0. DP = 1 means the dot is off.
