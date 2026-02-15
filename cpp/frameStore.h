/* ----------------------------------------------------------
**   frameStore.h
**
**   Algorithmic level model of Drawing engine
**
**   Frame store module (header file)
**
**   version 0.2  15/10/2007
**   contributors: lplana, jpepper, lbrackenbury
**
---------------------------------------------------------- */
#ifndef FSINC
#define FSINC

#include <iostream>
#include <cstdlib>
#include <cstdint>

#include "params.h"

class FrameStore {
    private:
        /* declare the memory buffer */
        uint8_t *membuf;
        uint8_t *handshake;

    public:
        uint8_t read(int address);
        void write(int address, uint8_t colour);

        /* the constructor points the memory buffer to a buffer passed */
        /* as a parameter (such as the screen shared memory buffer)    */
        FrameStore(uint8_t *mem) {
            membuf = mem;
            handshake = mem+SHMSZ-1;
        }
};

#endif
