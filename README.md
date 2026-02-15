# RISC-V SoC Hardware Accelerator for Conway’s Game of Life

A fully synthesised hardware accelerator for [Conway’s Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) integrated into a RISC-V SoC.

---

## Overview

The module computes Conway’s Game of Life directly in RTL and writes into a framestore (or two for double buffering) connected to a Video Display Controller Unit (VDCU).

## Demonstration

A demo of ```examples/line.s``` with colour too!

<video width="100%" controls>
  <source src="https://github.com/user-attachments/assets/5f663621-f2a8-47b2-b436-b69c17e4ec3e" type="video/mp4">
</video>

<img src="https://github.com/user-attachments/assets/9eda42de-6548-4259-bfa5-faf744f877d0" width="100%">

## Some Cool Optimisations

First, some hardware constraints:
- 32-bit shared memory bus
- 40MHz processor clock speed
- 96% of Block RAM already used by processor memory

### Rotating Row Buffers & 3×3 Sliding Window

To avoid repeatedly fetching neighbouring pixels from memory, I used three row buffers:

```
rtl/game_of_life.sv

logic [641:0] row_buffer [0:2];     // 3-row buffer, 642 bits wide (for 0-padding on left/right)
```

All 8 neighbours are evaluated in one clock cycle and the 3x3 window over the row buffers is slid by simply incrementing ```x_compute``` on each iteration:

```
rtl/game_of_life.sv

assign neighbour_count = row_buffer[0][x_compute - 1] + row_buffer[0][x_compute] + row_buffer[0][x_compute + 1] +
                         row_buffer[1][x_compute - 1] + 0                        + row_buffer[1][x_compute + 1] +
                         row_buffer[2][x_compute - 1] + row_buffer[2][x_compute] + row_buffer[2][x_compute + 1];
```

This way, each framestore row must only be read once and we avoid using the scarce BRAM entirely.

### Buffering Writes to Memory

Naively writing each pixel (8-bit) would require one bus transaction per compute cycle, instead:

- Buffer 4 × 8-bit pixels
- Write as one aligned 32-bit word
- Assert `de_req` once every 4 cycles

This gives a free and easy 75% reduction in write traffic without a loss in throughput on the shared system bus :)


### Double Buffering + RISC-V Control

The framestore is [double-buffered](https://en.wikipedia.org/wiki/Multiple_buffering#Double_buffering_in_computer_graphics), Frame A is read from while Frame B is written to:

```
examples/line.s

; -----------------------------------------------------
; Generation 1: Read Frame 0, Write Frame 1
; -----------------------------------------------------
LI      a0, F0_WORD             ; Read Base
LI      a1, F1_WORD             ; Write Base
JAL     ra, run_gol             ; Run Game of Life
JAL     ra, wait_engine         ; Idle until engine free
LI      t0, F1_BYTE
SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 1

; -----------------------------------------------------
; Generation 2: Read Frame 1, Write Frame 0
; -----------------------------------------------------
LI      a0, F1_WORD             ; Read Base
LI      a1, F0_WORD             ; Write Base
JAL     ra, run_gol             ; Run Game of Life
JAL     ra, wait_engine         ; Idle until engine free
LI      t0, F0_BYTE
SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 0
```

This prevents [flickering](https://en.wikipedia.org/wiki/Flicker_(screen)) and lets a program run smoothly even at high speeds of animation.

## Verification & Tooling

Includes a software model ```cpp/gameoflife.cpp```, golden data generation ```scripts/test_generator.sh``` and a testbench ```testing/gol_Testbench.sv``` achieving 100% coverage on:
- FSM state transitions
- Conditional branches 
- Statements

## Resource Utilisation

![5932BB07-0402-4413-BDD5-D4A7E53CDADC_4_5005_c](https://github.com/user-attachments/assets/a00c5408-91b0-4a65-8835-44d217bec104)

### Game of Life Unit
- LUTs: 3344
- Flip-Flops: 2100
- DSPs: 4
- BRAM: 0

### Total SoC
- 38% LUT utilisation
- 12% Flip-Flops
- 96% Block RAM

The unit accounts for roughly a quarter of total SoC logic resources.

