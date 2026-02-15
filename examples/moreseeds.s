;-----------------------------------------------------
;
;       Phase 4: Game of Life Animation
;       Target: COMP32211 RISC-V
;       Date:   December 2025
;
;       Description:
;       Initialises the screen and runs an infinite 
;       double-buffered animation loop on: 
;           Pattern 1: Large Glider Gun
;           Pattern 2: Horizontal Lines
;           Pattern 3: Grid Pattern
;           Pattern 4: Diagonal Lines
;
;-----------------------------------------------------

        ORG 0
        J main

; ================================== Header ===================================

; MEMORY MAP
; 0x00000 - 0x00FFF Words: Program Code (Reserved)
; 0x01000 - 0x13BFF Words: Frame 0
; 0x13C00 - 0x267FF Words: Frame 1

VDUC_BASE       EQU     0x10600
VDUC_DISPLAY    EQU     0x0             

DRAW_BASE       EQU     0x10800
DRAW_R0         EQU     0x00
DRAW_R1         EQU     0x04
DRAW_R2         EQU     0x08
DRAW_R3         EQU     0x0C
DRAW_R4         EQU     0x10
DRAW_R5         EQU     0x14
DRAW_R6         EQU     0x18
DRAW_R7         EQU     0x1C
DRAW_COMMAND    EQU     0x20
DRAW_STATUS     EQU     0x24

F0_WORD    EQU    0x01000         ; Start Frame 0 at 4KB offset (Word addr 0x1000)
F1_WORD    EQU    0x13C00         ; Frame 1 starts 76800 words later
F0_BYTE    EQU    0x04000         ; Byte Address (0x1000 * 4)
F1_BYTE    EQU    0x4F000         ; Byte Address (0x13C00 * 4)

ALIVE           EQU     0xFF            ; White
DEAD            EQU     0x00            ; Black
DELAY           EQU     50000           ; Speed of animation (lower = faster)
ITERATIONS      EQU     50              ; Iterations before switching animations

; ================================== Main Program =================================

main:   LI      s0, DRAW_BASE
        LI      s1, VDUC_BASE
        LA      sp, stack

        ; -----------------------------------------------------
        ; 1. Clear Frame 0 (Front Buffer)
        ; -----------------------------------------------------
        LI      t0, F0_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Point VDUC to Frame 0
        LI      a0, DEAD
        LI      a1, F0_BYTE
        JAL     ra, clear_screen

        ; -----------------------------------------------------
        ; 2. Clear Frame 1 (Back Buffer)
        ; -----------------------------------------------------
        LI      t0, F1_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Point VDUC to Frame 1               
        LI      a0, DEAD
        LI      a1, F1_BYTE
        JAL     ra, clear_screen

        J       demo_loop

        ; -----------------------------------------------------
        ; 3. Setup for Animation
        ; -----------------------------------------------------
        ; LI      t0, F0_BYTE
        ; SW      t0, VDUC_DISPLAY[s1]    ; Point VDUC back to Frame 0
        ; JAL     draw_glider_gun         ; Draw seed on Frame 0

animation_loop:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        LI      t1, ITERATIONS

        loop:

        ; -----------------------------------------------------
        ; Generation 1: Read Frame 0, Write Frame 1
        ; -----------------------------------------------------
        LI      a0, F0_WORD             ; Read Base
        LI      a1, F1_WORD             ; Write Base
        JAL     run_gol             ; Run Game of Life
        JAL     wait_engine         ; Idle until engine free
        LI      t0, F1_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 1

        LI      a0, DELAY
        JAL     delay_loop

        ; -----------------------------------------------------
        ; Generation 2: Read Frame 1, Write Frame 0
        ; -----------------------------------------------------
        LI      a0, F1_WORD             ; Read Base
        LI      a1, F0_WORD             ; Write Base
        JAL     run_gol             ; Run Game of Life
        JAL     wait_engine         ; Idle until engine free
        LI      t0, F0_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 0

        LI      a0, DELAY
        JAL     delay_loop

        ADDI    t1, t1, -1
        BNEZ    t1, loop

        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

demo_loop:
        ; -----------------------------------------------------
        ; Pattern 1: Large Glider Gun (Frame 0)
        ; -----------------------------------------------------
        LI      t0, F0_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Set display to Frame 0
        LI      a0, DEAD
        JAL     clear_screen
        JAL     draw_large_glider_gun
        JAL     animation_loop

        ; -----------------------------------------------------
        ; Pattern 2: Horizontal Lines (Frame 1)
        ; -----------------------------------------------------
        LI      t0, F1_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 1
        LI      a0, DEAD
        JAL     clear_screen
        JAL     draw_test_lines
        JAL     animation_loop

        ; -----------------------------------------------------
        ; Pattern 3: Grid Pattern (Frame 0)
        ; -----------------------------------------------------
        LI      t0, F0_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 0
        LI      a0, DEAD
        JAL     clear_screen
        JAL     draw_grid_pattern
        JAL     animation_loop

        ; -----------------------------------------------------
        ; Pattern 4: Diagonal Lines (Frame 1)
        ; -----------------------------------------------------
        LI      t0, F1_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 1
        LI      a0, DEAD
        JAL     clear_screen
        JAL     draw_diagonal_pattern
        JAL     animation_loop

        J       demo_loop

; -----------------------------------------------------
; Arguments: a0 = Colour (R0)
; -----------------------------------------------------
clear_screen:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        JAL     ra, wait_engine
        SW      a0, DRAW_R0[s0]
        SW      zero, DRAW_COMMAND[s0]  ; Command 0: Clear
        
        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

; -----------------------------------------------------
; Description: Draws horizontal line
; -----------------------------------------------------
draw_seed:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        JAL     ra,   wait_engine
        LI      t0,   100
        SW      t0,   DRAW_R0[s0]       ; m (dx)
        SW      zero, DRAW_R1[s0]       ; n (dy)
        LI      t0,   1
        SW      t0,   DRAW_R2[s0]       ; s1
        SW      t0,   DRAW_R3[s0]       ; s2
        LI      t0,   0x204C8           ; Start at (200, 200) + Offset           
        SW      t0,   DRAW_R4[s0]       ; 0x1F4C8 + 0x1000 = 0x204C8
        SW      zero, DRAW_R5[s0]
        LI      t0,   ALIVE
        SW      t0,   DRAW_R6[s0]
        LI      t0,   1
        SW      t0,   DRAW_COMMAND[s0]  ; Command 1: Draw Line
        
        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

; -----------------------------------------------------
; Large Glider Gun - Scaled 12x, Centered
; Base position: X=120, Y=140 (more centered)
; -----------------------------------------------------
draw_large_glider_gun:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        LI      t1, ALIVE
        SW      t1, DRAW_R6[s0]
        LI      t1, 1
        SW      t1, DRAW_R2[s0]
        SW      t1, DRAW_R3[s0]
        SW      zero, DRAW_R5[s0]

        ; ROW 5 (Y=140+5*12=200) - Cells 1,2
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        SW      zero, DRAW_R1[s0]
        LI      t0, 0x1F5A0             ; (200*640)+(120+1*12)
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 6 (Y=212) - Cells 1,2
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x219A0
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 3 (Y=176) - Cells 11,12
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1BC64             ; (176*640)+(120+11*12)
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 4 (Y=188) - Cell 10
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1DF50
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 4 - Cell 14
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1DF80
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 5 - Cell 9
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1F560
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 5 - Cell 15
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1F5B4
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 6 - Cell 9
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x21960
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 6 - Cell 13
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x219A8
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 6 - Cells 15,16
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x219B4
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 7 - Cell 9
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x23D60
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 7 - Cell 15
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x23DB4
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 8 - Cell 10
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x26150
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 8 - Cell 14
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x26180
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 9 - Cells 11,12
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x28564
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; Right side - ROW 3 - Cells 21,22
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1BCE8
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 4 - Cells 21,22
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1DFE8
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 5 - Cells 21,22
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1F5E8
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 2 - Cell 23
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x199FC
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 6 - Cell 23
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x219FC
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 1 - Cell 25
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x17A14
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 7 - Cell 25
        JAL     wait_engine
        LI      t0, 12
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x23E14
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 3 - Cells 35,36
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1BD8C
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        ; ROW 4 - Cells 35,36
        JAL     wait_engine
        LI      t0, 24
        SW      t0, DRAW_R0[s0]
        LI      t0, 0x1E08C
        SW      t0, DRAW_R4[s0]
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]

        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

; -----------------------------------------------------
; Test Pattern: Multiple Horizontal Lines
; -----------------------------------------------------
draw_test_lines:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        LI      t1, ALIVE
        SW      t1, DRAW_R6[s0]
        LI      t1, 1
        SW      t1, DRAW_R2[s0]
        SW      t1, DRAW_R3[s0]
        SW      zero, DRAW_R1[s0]
        SW      zero, DRAW_R5[s0]

        ; Draw 10 horizontal lines across screen
        LI      t2, 10                  ; Counter
        LI      t3, 50                  ; Starting Y
draw_line_loop:
        JAL     wait_engine
        LI      t0, 540                 ; Length (640-100 for margins)
        SW      t0, DRAW_R0[s0]
        
        ; Calculate address: (Y * 640) + 50
        LI      t0, 640
        MUL     t4, t3, t0
        ADDI    t4, t4, 50
        LI      t0, 0x4000              ; Frame base
        ADD     t4, t4, t0              ; Add frame base
        SW      t4, DRAW_R4[s0]
        
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]
        
        ADDI    t3, t3, 40              ; Y += 40
        ADDI    t2, t2, -1
        BNEZ    t2, draw_line_loop

        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

; -----------------------------------------------------
; Grid Pattern
; -----------------------------------------------------
draw_grid_pattern:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        LI      t1, ALIVE
        SW      t1, DRAW_R6[s0]
        LI      t1, 1
        SW      t1, DRAW_R2[s0]
        SW      t1, DRAW_R3[s0]
        SW      zero, DRAW_R5[s0]

        ; Horizontal grid lines
        LI      t2, 12                  ; Number of lines
        LI      t3, 40                  ; Starting Y
grid_h_loop:
        JAL     wait_engine
        LI      t0, 560
        SW      t0, DRAW_R0[s0]
        SW      zero, DRAW_R1[s0]
        
        LI      t0, 640
        MUL     t4, t3, t0
        ADDI    t4, t4, 40
        LI      t0, 0x4000              ; Frame base
        ADD     t4, t4, t0
        SW      t4, DRAW_R4[s0]
        
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]
        
        ADDI    t3, t3, 40
        ADDI    t2, t2, -1
        BNEZ    t2, grid_h_loop

        ; Vertical lines (using small horizontal segments stacked)
        LI      t2, 14                  ; Number of vertical lines
        LI      t5, 40                  ; Starting X
grid_v_loop:
        LI      t3, 40                  ; Y position
        LI      t6, 11                  ; Segments per vertical line
grid_v_segment:
        JAL     wait_engine
        LI      t0, 1                   ; Width
        SW      t0, DRAW_R0[s0]
        SW      zero, DRAW_R1[s0]
        
        LI      t0, 640
        MUL     t4, t3, t0
        ADD     t4, t4, t5
        LI      t0, 0x4000              ; Frame base
        ADD     t4, t4, t0
        SW      t4, DRAW_R4[s0]
        
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]
        
        ADDI    t3, t3, 40
        ADDI    t6, t6, -1
        BNEZ    t6, grid_v_segment
        
        ADDI    t5, t5, 40
        ADDI    t2, t2, -1
        BNEZ    t2, grid_v_loop

        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

; -----------------------------------------------------
; Diagonal Pattern
; -----------------------------------------------------
draw_diagonal_pattern:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        LI      t1, ALIVE
        SW      t1, DRAW_R6[s0]
        LI      t1, 1
        SW      t1, DRAW_R2[s0]
        SW      t1, DRAW_R3[s0]
        SW      zero, DRAW_R5[s0]

        ; Draw diagonal lines
        LI      t2, 8                   ; Number of diagonals
        LI      t3, 0                   ; Starting offset
diag_loop:
        JAL     wait_engine
        LI      t0, 400                 ; Length
        SW      t0, DRAW_R0[s0]
        SW      zero, DRAW_R1[s0]
        
        ; Start at (t3, 40)
        LI      t0, 640
        LI      t4, 40
        MUL     t4, t4, t0
        ADD     t4, t4, t3
        LI      t0, 0x4000              ; Frame base
        ADD     t4, t4, t0
        SW      t4, DRAW_R4[s0]
        
        LI      t0, 1
        SW      t0, DRAW_COMMAND[s0]
        
        ADDI    t3, t3, 80
        ADDI    t2, t2, -1
        BNEZ    t2, diag_loop

        LW      ra, [sp]
        ADDI    sp, sp, 4
        RET

; -----------------------------------------------------
; Arguments: a0 = Read Base, a1 = Write Base
; -----------------------------------------------------
run_gol:
        SW      a0, DRAW_R0[s0]          ; Read Base
        SW      a1, DRAW_R1[s0]          ; Write Base
        LI      t0, 640
        SW      t0, DRAW_R2[s0]          ; Width
        LI      t0, 480
        SW      t0, DRAW_R3[s0]          ; Height
        LI      t0, ALIVE
        SW      t0, DRAW_R4[s0]          ; Alive
        LI      t0, DEAD
        SW      t0, DRAW_R5[s0]          ; Dead
        LI      t0, 2
        SW      t0, DRAW_COMMAND[s0]     ; Command 2: Game of Life
        RET

wait_engine:
        LW      t0, DRAW_STATUS[s0]
        ANDI    t0, t0, 0xFF
        BNEZ    t0, wait_engine
        RET

delay_loop:
        ADDI    a0, a0, -1
        BNEZ    a0, delay_loop
        RET

; =================================== User Stack Space ================================= 

DEFS 0x1024
stack: