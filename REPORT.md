# ECE 3300 · Design Quiz 2 · The Order Queue — Work Report

This report covers what was missing, what was broken, how each problem was found, the exact fix, how each fix was verified, and what was deliberately left unchanged.

---

## 1. Summary

| Item | Status |
|---|---|
| Missing module `fifo_flags.v` | Written (3 `assign` lines) |
| Bugs found and fixed | 4 of 4 (3 found in simulation, 1 board-only in the XDC) |
| `btn_pulse_tb` | `done: 0 errors` |
| `fifo_sync_tb` | `done: 0 errors` |
| `top_queue_tb` | `done: 0 errors` |
| Synthesis / Implementation / Bitstream | Complete, no errors, the word "latch" does not appear |
| Board (Nexys A7-100T) | Programmed. Push, pop, count LEDs, EMPTY, reset and the served digit behave as in Section 3 |
| Files not changed | All 3 testbenches, every port name, `DB_MAX`, `sseg_hex.v`, `top_queue.v` |

Files changed: `fifo_flags.v` (written), `btn_pulse.v` (1 line), `fifo_sync.v` (2 lines), `top_queue.xdc` (2 lines).

All line numbers below refer to the **original** starter files (kept unchanged in `quiz_queue_ORIGINAL/`).

---

## 2. What was missing: `fifo_flags.v`

The FIFO has 8 slots (3 address bits). Each pointer has a 4th bit, the **lap bit**, which flips every time the pointer goes all the way round the 8 slots. `fifo_flags` turns the two pointers into the three status outputs.

```verilog
assign empty = (wptr == rptr);                                       // same slot, same lap
assign full  = (wptr[3] != rptr[3]) && (wptr[2:0] == rptr[2:0]);    // same slot, writer one lap ahead
assign count = wptr - rptr;                                          // 4-bit subtraction wraps mod 16
```

**Why FULL needs bit 3.** With only the 3 address bits, the two pointers are equal in two different situations:
- nobody is waiting (EMPTY), and
- the writer has gone all the way round and caught up with the reader (FULL).

The lap bit tells them apart:

| | wptr | rptr | bits 2..0 | bit 3 | Result |
|---|---|---|---|---|---|
| EMPTY example | 0_000 | 0_000 | equal | equal | empty = 1, count = 0 |
| FULL example | 1_000 | 0_000 | equal | different | full = 1, count = 8 |

**Why count is right after wrap-around.** The subtraction is done in 4 bits (mod 16). Example: wptr = 0_010, rptr = 1_110 gives 2 − 14 = −12, and −12 + 16 = 4. Because the pointers are 4 bits (twice the depth), the difference is always the true number of entries, 0..8.

`assign` was used instead of `always @(*)`, so no output can be left unassigned and no latch can be inferred. The port list was not changed.

**Proof:** `fifo_sync_tb` C1 (`empty=1 full=0 count=0`) and C5 (`empty=0 full=1 count=8`) pass.

---

## 3. The 4 bugs

### Bug 1 — `btn_pulse.v : 34` — edge detector was a level detector

```diff
-    assign pulse = stable & stable_d;
+    assign pulse = stable & ~stable_d;
```

**What was wrong and why.** `stable & stable_d` is 1 when the button is down now **and** was down one clock ago. That is true on every clock the button is held, so one press produced a pulse on every clock: one push per clock, not one per press. A rising edge means "1 now, **0** one clock ago", so `stable_d` must be inverted. After the fix, `pulse` is 1 on only the one clock right after `stable` goes 0 → 1.

**How found.** `btn_pulse_tb`:
```
B2 one press, held 40 clocks   pulses=33 (widest 33 clock)
   FAIL B2 one press, held 40 clocks  : got 33 pulses, expected 1
B4 pulse width = 39 clock(s)
   FAIL B4 pulse width: got 39 clocks, expected 1
done: 5 errors
```
**After the fix:** `done: 0 errors` (B7 shows 2 pulses, widest 1 clock).

---

### Bug 2 — `fifo_sync.v : 26` — a push was accepted when FULL

```diff
-    wire do_wr = wr_en;
+    wire do_wr = wr_en & ~full;
```

**What was wrong and why.** The comment above the line says "a push is only a push if there is room", but `do_wr` ignored `full`. When the FIFO held 8 orders, a 9th push still wrote F into slot `wptr[2:0]` = slot 0. That overwrote order 1, the oldest one still waiting, and moved `wptr` on, so count became 9 and FULL turned off. The spec says a push when full is turned away and nothing inside is lost. The fix gates the write with `~full`, the same way the line below gates the read with `~empty`.

**How found.** `fifo_sync_tb` (first FAIL):
```
C6 push F when FULL: ignored       empty=0 full=0 count=9
   FAIL C6 push F when FULL: ignored      : expected empty=0 full=1 count=8
C6 drain: 1..8 in order, never F   dout=f
   FAIL C6 drain: 1..8 in order, never F  : dout=f, expected 1
```
**After the fix:** C6 and C7 pass.

---

### Bug 3 — `fifo_sync.v : 32` — read pointer was never reset

```diff
         if (rst) begin
             wptr <= 4'd0;
-            wptr <= 4'd0;
+            rptr <= 4'd0;
             dout <= 4'd0;
```

**What was wrong and why.** The reset branch assigned `wptr` twice and never assigned `rptr`. After a reset in the middle of use, `wptr` went to 0 but `rptr` kept its old value (2 in the testbench). The pointers were no longer equal, so EMPTY = 0 and count = 0 − 2 = −2 = 14 in 4 bits. A pop after the reset read a stale slot. A reset must return **both** pointers to 0 so the FIFO is empty.

This bug is hidden at power-up: `rptr` is declared with initial value 0, so the first reset looks correct. It only shows after some pops (rptr ≠ 0) followed by a reset. That is why the testbench does two pops before the C8 reset.

**How found.** `fifo_sync_tb` (first FAIL after bugs 1 and 2 were fixed):
```
C8 reset in the middle             empty=0 full=0 count=14
   FAIL C8 reset in the middle            : expected empty=1 full=0 count=0
C8 after reset: push 6, pop        dout=4
   FAIL C8 after reset: push 6, pop       : dout=4, expected 6
done: 3 errors
```
`top_queue_tb`:
```
T9 reset: EMPTY, digit 0 LED=0000000000001100 SEG=1000000
   FAIL: expected LED=0100000000000000 SEG=1000000
done: 1 errors
```
**After the fix:** all three testbenches print `done: 0 errors`.

---

### Bug 4 — `top_queue.xdc : 9–10` — BTNU and BTND pins swapped (board-only)

```diff
-set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {BTNU}]
-set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {BTND}]
+set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {BTNU}]
+set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {BTND}]
```

**What was wrong and why.** In the Digilent Nexys A7-100T master XDC, **M18 = BTNU** (top) and **P18 = BTND** (bottom). The starter file had them the other way round, so the top button was wired to the pop logic and the bottom button to the push logic. The testbenches drive the ports by **name** and never see package pins, so every simulation passed with this bug. It can only be seen on the board.

**How found.** All simulations passed, so following the "golden rule" (sim passes, board wrong → suspect the XDC), every pin in the XDC was compared with the master XDC. Only these two lines differed. Section 3 **row 2** would fail: after BTNC, set SW = 0011 and press BTNU (top). That button really drives pop, and popping an empty line does nothing, so LD3..LD0 stays 0000 and LD14 (EMPTY) stays ON instead of showing 0001. Pressing BTND would push instead.

**After the fix:** on the board, BTNU pushes (count goes up by one per press), BTND pops, and the rows of Section 3 match.

The fix was made in the XDC, where the bug is. Swapping `push`/`pop` in `top_queue.v` instead would hide the bug in the wrong file (−5 per Section 8).

---

## 4. What was checked and deliberately NOT changed

"Fixing" code that was not broken costs −3 per change, so these were checked line by line and left alone:

| File / item | Why it is correct |
|---|---|
| `sseg_hex.v` | All 16 patterns (0–F) are correct for active-low `{g,f,e,d,c,b,a}` |
| `top_queue.v` | Reset synchronizer, `btn_pulse` instances, FIFO wiring, `LED = {full, empty, 10'b0, count}`, `DP = 1`, `AN = 8'b1111_1110` are all correct |
| `DB_MAX = 1_000_000` | Correct (10 ms at 100 MHz). Changing it is −3 and makes D2 fail from bouncing |
| `btn_pulse.v` counter width | 20 bits holds up to 1,048,575, which is more than DB_MAX − 1 = 999,999 |
| `btn_pulse.v` synchronizer and debounce | Correct |
| XDC clock, switch, LED, SEG, DP, AN pins | All match the master XDC |
| Testbenches | Unchanged (they must be the originals) |
| Port names | Unchanged (otherwise the testbenches do not compile) |

Only comments were added next to the fixed lines.

---

## 5. Verification

### Simulation (Vivado xsim)
Each testbench: Set as Top → Run Behavioral Simulation → `run all`.

| Testbench | Before fixes (with fifo_flags written) | After all fixes |
|---|---|---|
| `btn_pulse_tb` | `done: 5 errors` | `done: 0 errors` |
| `fifo_sync_tb` | `done: 37 errors` | `done: 0 errors` |
| `top_queue_tb` | `done: 7 errors` | `done: 0 errors` |

Final `top_queue_tb` output:
```
T3 push 7, A: count 3    LED=0000000000000011 SEG=1000000
T4 pop: digit 3, count 2 LED=0000000000000010 SEG=0110000
T4 pop: digit 7, count 1 LED=0000000000000001 SEG=1111000
T4 pop: digit A, EMPTY   LED=0100000000000000 SEG=0001000
T5 pop when EMPTY        LED=0100000000000000 SEG=0001000
T6 push 1..8: FULL       LED=1000000000001000 SEG=0001000
T7 push F when FULL      LED=1000000000001000 SEG=0001000
T8 pop: digit 1, count 7 LED=0000000000000111 SEG=1111001
T9 reset: EMPTY, digit 0 LED=0100000000000000 SEG=1000000
done: 0 errors
```
(LED bits read left to right: LED15 = FULL, LED14 = EMPTY, LED13..4 = 0, LED3..0 = count. SEG is active low, `gfedcba`.)

### Build
- Part `xc7a100tcsg324-1`, top `top_queue`.
- Synthesis, implementation and `write_bitstream` completed with no errors.
- The word "latch" does not appear in the synthesis messages. The only warnings are that LED[13:4] are driven by constant 0, which is intended.
- Bitstream: `quiz_queue_proj/quiz_queue_proj.runs/impl_1/top_queue.bit`.

### Board
Observed on the Nexys A7: BTNU adds an order and BTND serves one, with the count in binary on LD3..LD0. LD14 is on at count 0. BTNC resets everything to 0. BTNL and BTNR do nothing (they are unused). The rightmost digit shows the order number that was **served last**: it does not change on a push, only on a pop. With SW = 0000 every order is 0, so it shows 0.

---

## 6. Debug order (method)

1. Wrote `fifo_flags` first. Without it, `empty`, `full` and `count` are undriven (z/x) and every check fails.
2. `btn_pulse_tb` → first FAIL at B2 → bug 1.
3. `fifo_sync_tb` → first FAIL at C6 → bug 2. Rerun → first FAIL at C8 → bug 3.
4. `top_queue_tb` → T9 FAIL disappeared with bug 3 → `done: 0 errors`.
5. All simulations passed → the remaining bug must be outside the RTL → compared the XDC with the master XDC → bug 4.

Always fix the **first** FAIL line first: later FAILs are often caused by an earlier bug (for example, the C7 failures were caused by the bad push in C6).

---

## 7. Likely questions and answers

1. **Why two flip-flops on the button inputs?** The button is not synchronized to the clock. A flip-flop that samples it while it changes can go metastable. The second flip-flop gives it a full clock to settle, so the rest of the logic sees a clean 0 or 1.
2. **Why debounce?** A mechanical button bounces for a few ms, which would look like several presses and push several orders. The input must stay the same for DB_MAX clocks (10 ms) before it is believed.
3. **Why an edge detector?** A press lasts millions of clocks, and we want exactly one push per press, so only the clock where `stable = 1` and `stable_d = 0` makes a pulse.
4. **Why does reset not use `btn_pulse`?** Reset is a level ("held = stay reset"). Bouncing does not matter, because resetting twice gives the same result. It still goes through two flip-flops (`rsync`) for synchronization.
5. **Why is count 4 bits?** It must show 0 to 8. That is 9 values, and 3 bits only go to 7.
6. **Why `mem[wptr[2:0]]`?** There are only 8 slots, so the address is bits 2..0. Bit 3 only marks the lap.
7. **Why did the simulation not catch the XDC bug?** Testbenches connect to ports by name. Package pins only matter on the real FPGA.
8. **What causes a latch?** A combinational `always @(*)` where an output is not assigned on every path (an `if` with no `else`, or a `case` with no `default`). Using `assign` avoids it.
9. **What happens on a pop when empty?** `do_rd = 0`, so `dout` keeps its value and the digit keeps showing the last order served (row 8).
10. **Push and pop on the same clock?** Both happen: one in, one out, count unchanged (C7).
11. **Why does the digit stay 0 while pushing?** The digit shows the last order **served** (`dout`), which only changes on a pop.
12. **Active low:** SEG bit 0 = segment ON. `AN = 1111_1110` turns on only digit 0. `DP = 1` means the dot is off.

---
