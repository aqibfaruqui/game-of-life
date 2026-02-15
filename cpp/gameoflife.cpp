/* ----------------------------------------------------------
**
** Algorithmic level model of Drawing engine
** 2D Conway's Game of Life Implementation
**
** Author:   Aqib Faruqui
** Date:     November 2025
**
---------------------------------------------------------- */

#include "gameoflife.h"
#include <vector>

void GameOfLifeModule::drawGameOfLife(int alive_colour, int dead_colour, FrameStore& fs)
{
    // 1. Create a snapshot of the current state
    std::vector<std::vector<int>> current_state(LINES, std::vector<int>(PIXELS));

    // Read current frame from FrameStore
    for (int y = 0; y < LINES; y++) {
        for (int x = 0; x < PIXELS; x++) {
            int address = (PIXELS * y) + x;
            int pixel_val = fs.read(address);
            if (pixel_val == alive_colour) {
                current_state[y][x] = 1;
            } else {
                current_state[y][x] = 0;
            }
        }
    }

    // 2. Compute Next Generation
    for (int y = 0; y < LINES; y++) {
        for (int x = 0; x < PIXELS; x++) {
            int neighbors = 0;
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;

                    int ny = y + dy;
                    int nx = x + dx;

                    // Boundary check: Treat edges as dead
                    if (ny >= 0 && ny < LINES && nx >= 0 && nx < PIXELS) {
                        neighbors += current_state[ny][nx];
                    }
                }
            }

            /* 
             * Game of Life Rules:
             *
             * 1. Any live cell with fewer than two live neighbours dies, as if by underpopulation.
             * 2. Any live cell with two or three live neighbours lives on to the next generation.
             * 3. Any live cell with more than three live neighbours dies, as if by overpopulation.
             * 4. Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
             */

            int is_alive = current_state[y][x];
            int next_state = 0;

            if (is_alive) {
                if (neighbors == 2 || neighbors == 3) {
                    next_state = 1;     // Stay Alive
                } else {
                    next_state = 0;     // Die (Under/Overpopulation)
                }
            } else {
                if (neighbors == 3) {
                    next_state = 1;     // Reproduction
                }
            }

            // 3. Write back to FrameStore
            int address = (PIXELS * y) + x;
            fs.write(address, next_state ? alive_colour : dead_colour);
        }
    }
}