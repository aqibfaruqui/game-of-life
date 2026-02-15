/* ----------------------------------------------------------
**   params.h
**
**   Algorithmic level model of Drawing engine
**
**   Parameters file
**
**   version 0.2  15/10/2007
**   contributors: lplana, jpepper, lbrackenbury
**
---------------------------------------------------------- */
#ifndef PRMINC
#define PRMINC
 

/* --- screen --- */
#define PIXELS 640 /* screen width  */
#define LINES  480 /* screen height */

/* --- virtual screen --- */
#define SHMSZ    (PIXELS*LINES)+1 /* size of the shared memory buffer */
#define BLACK    0x00         /* code for colour BLACK */
#define WHITE    0xFF         /* code for colour WHITE */
#define CLOSESCR true         /* close the virtual screen on exit */

/* --- command interpreter --- */
#define CMDBUF   80   /* length of command buffer */
#define MAXPARAM 5    /* maximum number of parameters in command */
#define VERBOSE  true /* show executed commands in terminal */

#endif
