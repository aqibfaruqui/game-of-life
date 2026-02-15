/* ----------------------------------------------------------
** gameoflife.h
**
** Algorithmic level model of Drawing engine
** 2D Conway's Game of Life Module
**
** Author:   Aqib Faruqui
** Date:     November 2025
**
---------------------------------------------------------- */
#ifndef GAMEOFLIFE_INC
#define GAMEOFLIFE_INC

#include "params.h"
#include "frameStore.h"

class GameOfLifeModule {
    public:
        void drawGameOfLife(int alive_colour, int dead_colour, FrameStore& fs);
};

#endif