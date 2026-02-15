;-----------------------------------------------------
;
;       Phase 4: Game of Life Animation
;       Target: COMP32211 RISC-V
;       Date:   December 2025
;
;       Description:
;       Initialises the screen, draws a seed line, 
;       and runs an infinite double-buffered animation loop
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

; Other cool colour combos
; ALIVE (0x1F) Cyan       + DEAD (0x02) Dark Blue
; ALIVE (0xE0) Bright Red + DEAD (0x40) Dim Red
; ALIVE (0xFC) Yellow     + DEAD (0x00) Black
; ALIVE (0xB6) Grey       + DEAD (0xFF) White
ALIVE           EQU     0xB6
DEAD            EQU     0xFF
DELAY           EQU     50000           ; Speed of animation (lower = faster)

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
        LI      a1, F0_WORD
        JAL     ra, clear_screen

        ; -----------------------------------------------------
        ; 2. Clear Frame 1 (Back Buffer)
        ; -----------------------------------------------------
        LI      t0, F1_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Point VDUC to Frame 1               
        LI      a0, DEAD
        LI      a1, F1_WORD
        JAL     ra, clear_screen

        ; -----------------------------------------------------
        ; 3. Setup for Animation
        ; -----------------------------------------------------
        LI      t0, F0_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Point VDUC back to Frame 0
        JAL     ra, draw_seed           ; Draw seed line on Frame 0

animation_loop:

        ; -----------------------------------------------------
        ; Generation 1: Read Frame 0, Write Frame 1
        ; -----------------------------------------------------
        LI      a0, F0_WORD             ; Read Base
        LI      a1, F1_WORD             ; Write Base
        JAL     ra, run_gol             ; Run Game of Life
        JAL     ra, wait_engine         ; Idle until engine free
        LI      t0, F1_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 1

        LI      a0, DELAY
        JAL     ra, delay_loop

        ; -----------------------------------------------------
        ; Generation 2: Read Frame 1, Write Frame 0
        ; -----------------------------------------------------
        LI      a0, F1_WORD             ; Read Base
        LI      a1, F0_WORD             ; Write Base
        JAL     ra, run_gol             ; Run Game of Life
        JAL     ra, wait_engine         ; Idle until engine free
        LI      t0, F0_BYTE
        SW      t0, VDUC_DISPLAY[s1]    ; Swap to Frame 0

        LI      a0, DELAY
        JAL     ra, delay_loop

        J       animation_loop

; ================================== Subroutines ==================================

; -----------------------------------------------------
; Arguments: a0 = Colour (R0)
;            a1 = Base Address
; -----------------------------------------------------
clear_screen:
        ADDI    sp, sp, -4
        SW      ra, [sp]

        JAL     ra, wait_engine
        SW      a0, DRAW_R0[s0]
        SW      a1, DRAW_R1[s0]
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
        LI      t0,   600
        SW      t0,   DRAW_R0[s0]       ; m (dx)
        SW      zero, DRAW_R1[s0]       ; n (dy)
        LI      t0,   1
        SW      t0,   DRAW_R2[s0]       ; s1
        SW      t0,   DRAW_R3[s0]       ; s2
        LI      t0,   0x29814           ; Start at (200, 200) + Offset           
        SW      t0,   DRAW_R4[s0]       ; 0x1F4C8 + 0x1000 = 0x204C8
        SW      zero, DRAW_R5[s0]
        LI      t0,   ALIVE
        SW      t0,   DRAW_R6[s0]
        LI      t0,   1
        SW      t0,   DRAW_COMMAND[s0]    ; Command 1: Draw Line
        
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