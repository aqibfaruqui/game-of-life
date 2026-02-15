/******************************************************************************/
/*                                                                            */
/* Module:   drawing_Testbench                                                */
/* Modified: December 2025                                                    */
/* Author:   J Garside, JSP, AMM, A Faruqui                                   */
/*                                                                            */
/******************************************************************************/

`timescale 1ns / 10ps
`define    VSCREEN  1

module drawing_Testbench();

localparam PERIOD         = 25;                  /* Corresponds to 40 MHz     */
localparam TIMEOUT        = 100000000;              /* Cycle limit on simulation */

localparam UNIT_CLEAR     = 0;             /* Define what each accelerator is */
localparam UNIT_LINE      = 1;
localparam UNIT_GOL       = 2;

// Offsets for Register locations
localparam R0             = 8'h00;
localparam R1             = 8'h04;
localparam R2             = 8'h08;
localparam R3             = 8'h0C;
localparam R4             = 8'h10;
localparam R5             = 8'h14;
localparam R6             = 8'h18;
localparam R7             = 8'h1C;
localparam GO             = 8'h20;
localparam STATUS         = 8'h24;
localparam STATUS_CLR     = 8'h28;
localparam STATUS_SET     = 8'h2C;
localparam DISPLAY_BASE   = 8'h30;
localparam DISPLAY_MODE   = 8'h34;
localparam DISPLAY_WIDTH  = 8'h38;
localparam DISPLAY_HEIGHT = 8'h3C;

localparam V_WIDTH        = 640;        /* Display width */
localparam V_HEIGHT       = 480;        /* Display height */
localparam V_MODE         = 2'b00;      /* Display mode (e.g., 16-bit colour) */
localparam V_BASE         = 18'h0000;   /* Display baseframe (not used here)  */

logic        clk;
logic        reset;

logic        de_req;             /* DE bus takes different form */ // WHAT???
logic        de_ack;
logic [17:0] de_addr;
logic  [3:0] de_nbyte;
logic [31:0] de_w_data;
logic        de_rnw;
logic [31:0] de_r_data;

logic        drawing_engine_cs;            /* Processor bus to accelerator(s) */
logic        drawing_engine_read;
logic        drawing_engine_write;
logic [31:0] drawing_engine_address;
logic  [1:0] drawing_engine_size;
logic  [1:0] drawing_engine_mode;
logic [31:0] drawing_engine_data_in;
logic [31:0] drawing_engine_data_out;
logic  [1:0] drawing_interrupts;

logic [31:0] data_test_buf;                      /* Buffer for test read data */

logic        CS_A;                                 /* VDU framestore read bus */
logic        read_A;
logic        write_A;
logic        stall_A;
logic  [1:0] size_A;
logic [19:0] addr_A;
logic [31:0] dwr_A;
logic [31:0] drd_A;

logic        CS_B;                                /* Processor framestore bus */
logic        read_B;
logic        write_B;
logic        stall_B;
logic  [1:0] size_B;
logic [19:0] addr_B;
logic [31:0] dwr_B;
logic [31:0] drd_B;

logic        fs_n_CS;                                       /* Framestore bus */
logic        fs_n_rd;
logic        fs_n_wr;
logic [17:0] fs_addr;
logic  [3:0] fs_n_bytes;
logic        fs_n_write;
logic [31:0] fs_d_in;
logic [31:0] fs_d_out;

logic fs_req, fs_ack;
logic [17:0] fs_addr2;

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

initial clk = 1;                                               /* Clock setup */
always #(PERIOD/2.0) clk <= !clk;

initial                      /* Simulation timeout in case of 'runaway' error */
begin
repeat (TIMEOUT) @ (posedge clk);
$stop;
end

initial                                                      /* Test stimulus */
  begin

  CS_B    <= 0;
  read_B  <= 0;
  write_B <= 0;
  size_B  <= 2'h2;
  addr_B  <= 18'h00000;
  dwr_B   <= 32'h0000_0000;

  reset <= 0;                                        /* Start up: reset pulse */
  repeat(3) @ (posedge clk);
  reset <= 1;
  repeat(3) @ (posedge clk);
  reset <= 0;
  @ (posedge clk);

  // Start a drawing unit
  bus_write(R0, 32'h0000_0000);                         /* Argument 0: Colour */
  bus_write(R1, 32'h0000_0000);                    /* Argument 1: Base address*/
  bus_write(GO, UNIT_CLEAR);               /* 'Go' command to Drawing unit #0 */
  wait_until_drawing_engine_not_busy(); /* Wait using the internal 'busy' bus */

  pre_process_line(270, 190, 370, 190, 8'h00, 8'hFF);
  wait_until_done();

  /* Test screen clear */
  bus_write(R0, 32'h0000_0000);                         /* Argument 0: Colour */
  bus_write(R1, 32'h0000_0000);                    /* Argument 1: Base address*/
  bus_write(GO, UNIT_CLEAR);               /* 'Go' command to Drawing unit #0 */
  wait_until_drawing_engine_not_busy(); /* Wait using the internal 'busy' bus */

  pre_process_line(270, 190, 370, 190, 8'h00, 8'hFF);
  wait_until_drawing_engine_not_busy();
  repeat(10) @ (posedge clk);
  
  /* First generation */
  draw_gameoflife(
      32'h00000,   // Read Base
      32'h00000,   // Write Base (Should be 32'h12C00 [76800 words offset] for double buffer)
      32'd640,     // Width
      32'd480,     // Height
      32'hFF,      // Alive (White)
      32'h00       // Dead (Black)
  );
  wait_until_drawing_engine_not_busy();
  repeat(10) @ (posedge clk);

  /* Second Generation (Double buffer) */
  draw_gameoflife(
      32'h00000,   // Read Base (Old Write Base) (Should be 32'h12C00 [76800 words offset] for double buffer)
      32'h00000,   // Write Base (Old Read Base)
      32'd640, 32'd480, 32'hFF, 32'h00
  );
  wait_until_drawing_engine_not_busy();
  repeat(10) @ (posedge clk);
  
  /* Third Generation */
  draw_gameoflife(
      32'h00000,   // Read Base (Old Write Base) 
      32'h00000,   // Write Base (Old Read Base) (Should be 32'h12C00 [76800 words offset] for double buffer)
      32'd640, 32'd480, 32'hFF, 32'h00
  );

  wait_until_done();                    /* Let processing proceed until done  */
  repeat(20) @ (posedge clk);
 
  $stop;                                /* Allow simulation to run to timeout */

end

/********************************************************/
/* System setup                                         */
/********************************************************/

/******************************************************************************/
/*  Instantiation of a mocked SRAM controller, VDUC                           */
/*  and the drawing_engine                                                    */
/*                                                                            */
/******************************************************************************/

drawing_engine u_drawing(
    .clk          (clk),
    .reset_i      (reset),
    .cs_i         (drawing_engine_cs),
    .read_i       (drawing_engine_read),
    .write_i      (drawing_engine_write),
    .address_i    (drawing_engine_address),
    .size_i       (drawing_engine_size),
    .mode_i       (drawing_engine_mode),
    .stall_o      (    ),                           /* Inactive in this model */
    .abort_v_o    (    ),                           /* Inactive in this model */
    .data_in      (drawing_engine_data_in),
    .data_out     (drawing_engine_data_out),
    .ireq_o       (drawing_interrupts),

    .v_mode_i     (V_MODE),                                      /* FROM VDUC */
    .v_base_i     (V_BASE),                                      /* FROM VDUC */
    .v_width_i    (V_WIDTH),                                     /* FROM VDUC */
    .v_height_i   (V_HEIGHT),                                    /* FROM VDUC */
  
    .de_req_o     (de_req),               /* To framestore controller/arbiter */
    .de_ack_i     (de_ack),
    .de_RnW_o     (de_rnw),
    .de_address_o (de_addr),
    .de_nbyte_o   (de_nbyte),
    .de_wr_data_o (de_w_data),
    .de_rd_data_i (de_r_data));

mock_sram_ctrl u_sram_ctrl(
    .clk       (clk       ),
    .reset     (reset     ),

    .CS_A      (CS_A),          /* VDU port inserts read requests for display */
    .read_A    (read_A ),
    .write_A   (write_A),
    .stall_A   (stall_A),
    .size_A    (size_A ),
    .addr_A    (addr_A ),
    .dwr_A     (dwr_A  ),
    .drd_A     (drd_A  ),

    .CS_B      (CS_B),            /* Processor port allows independent access */
    .read_B    (read_B ),
    .write_B   (write_B),
    .stall_B   (stall_B),
    .size_B    (size_B ),
    .addr_B    (addr_B ),
    .dwr_B     (dwr_B  ),
    .drd_B     (drd_B  ),

    .de_req    (de_req   ),         /* Accelerator port uses non-bus protocol */
    .de_ack    (de_ack   ),
    .de_addr   (de_addr  ),
    .de_nbyte  (de_nbyte ),
    .de_w_data (de_w_data),
    .de_rnw    (de_rnw   ),
    .de_r_data (de_r_data),

    .n_CS_o    (fs_n_CS),
    .n_rd_o    (fs_n_rd),
    .n_wr_o    (fs_n_wr),
    .addr_o    (fs_addr),
    .n_bytes_o (fs_n_bytes),
    .n_write_o (fs_n_write),
    .d_in_i    (fs_d_in),
    .d_out_o   (fs_d_out));

/* Mock up framestore */
mock_framestore u_mock_framestore(
    .n_CS_i     (fs_n_CS   ),
    .n_rd_i     (fs_n_rd   ),
    .n_wr_i     (fs_n_wr   ),
    .addr_i     (fs_addr   ),
    .n_bytes_i  (fs_n_bytes),
    .n_write_i  (fs_n_write),
    .d_load_o   (fs_d_in   ),
    .d_store_i  (fs_d_out  ),
    .use_vscreen(`VSCREEN));

mock_drawing_vduc vduc(.clk       (clk),     /* Simple video timing generator */
                       .reset     (reset),
                       .fs_req    (fs_req),
                       .fs_ack    (fs_ack),
                       .fs_addr_o (fs_addr2));          /* Data not used here */

assign CS_A    = fs_req;    /* Make up minimal read bus for VDU demonstration */
assign read_A  = fs_req;                          /* Only reads               */
assign write_A = 1'b0;                            /*             Never writes */
assign fs_ack  = read_A && !stall_A;              /* Acknowledge when granted */
assign size_A  = 2'h2;                            /* Word access              */
assign addr_A  = {fs_addr2, 2'h0};                /* Make byte address        */
assign dwr_A   = 0;

/*----------------------------------------------------------------------------*/
/* Microprocessor register write task
/* Call this following clock synchronisation for action at the next clock edge*/

task bus_write(input [7:0] addr, input [31:0] data);
begin
  $display("Writing %h: %h ", addr, data);

  drawing_engine_cs       <= #1  1'b1;            /* select drawing engine    */
  drawing_engine_address  <= #1 {24'h0, addr};    /* address within unit      */
  drawing_engine_read     <= #1  1'b0;            /* read disabled            */
  drawing_engine_write    <= #1  1'b1;            /* Write enabled            */
  drawing_engine_size     <= #1  2'b10;           /* size = 'word'            */
  drawing_engine_data_in  <= #1  data;
  @ (posedge clk);                                /* Wait for clock edge      */
  drawing_engine_cs       <= #1  1'b0;            /* Inactivate bus again     */
  drawing_engine_address  <= #1 32'hx;            /* This helps validate that */
  drawing_engine_read     <= #1  1'b0;            /* data has been -captured- */
  drawing_engine_write    <= #1  1'b0;
  drawing_engine_size     <= #1  2'bxx;

end
endtask

/*----------------------------------------------------------------------------*/
// Microprocessor register read task
/* Call this following clock synchronisation for action at the next clock edge*/

task bus_read(input [7:0] addr, output [31:0] data);
begin
  drawing_engine_cs       <= #1 1'b1;             /* select drawing engine    */
  drawing_engine_address  <= #1 {24'h0, addr};    /* address within unit      */
  drawing_engine_read     <= #1 1'b1;             /* read enabled             */
  drawing_engine_write    <= #1 1'b0;             /* Write disabled           */
  drawing_engine_size     <= #1 2'b10;            /* size = 'word'            */

  @ (posedge clk);                                /* Wait for clock edge      */
  data_test_buf <= #1 drawing_engine_data_out;
                                        /* Read data onto the 'processor' bus */

  drawing_engine_cs       <= #1  1'b0;            /* Inactivate bus again     */
  drawing_engine_address  <= #1 32'hx;            /* This helps validate that */
  drawing_engine_read     <= #1  1'b0;            /* data has been -captured- */
  drawing_engine_write    <= #1  1'b0;
  drawing_engine_size     <= #1  2'bxx;
end
endtask

/*----------------------------------------------------------------------------*/
/* This testbench task works by snooping on the status hierarchically; it     */
/* stall until the device-under-test has been active and the gone idle unless */
/* it times out.  Should be invoked at an active clock edge to ensure full    */
/* functionality.                                                             */

task automatic wait_until_drawing_engine_not_busy();
begin
  logic [31:0] data_test_buf = '0;
  integer not_busy_wait_counter = 0;
  integer max_clock_cycles = 1000000;  /* Set a limit to avoid infinite loops */

  if (u_drawing.bus_busy == 0)
    begin
    $write("Drawing engine is not busy at the start of the task.");
    $display("  Awaiting next change...");
    end

  while (u_drawing.bus_busy == 0) @ (posedge clk);     /* Ensure unit is busy */

  $display("Waiting for the drawing engine to become not busy...");
  // Wait until the drawing engine is not busy
  // Bottom 8 bits of the status register should be zero
  // This is a blocking task, so it will wait until the condition is met
  while((u_drawing.bus_busy != 0) && (not_busy_wait_counter < max_clock_cycles))
    begin
    @ (posedge clk) not_busy_wait_counter++;
    end

  if (not_busy_wait_counter > max_clock_cycles) begin
    $display("ERROR: Drawing engine did not become not busy within %d cycles",
              max_clock_cycles);
    $display("Last status read: %h", data_test_buf);
    $display("Simulation will terminate to prevent infinite loop.");
    $stop; // Terminate simulation if it takes too long
  end else
    $display("Drawing engine is not busy after %d cycles",
              not_busy_wait_counter);
end
endtask

/*----------------------------------------------------------------------------*/
// task automatic wait_until_done();

task wait_until_done();
begin
bus_read(STATUS, data_test_buf);
#2;              /* Delay wanted because 'data_test_buf' update delayed by #1 */
while (!data_test_buf[8])                                /* Status 'done' bit */
  begin
  bus_read(STATUS, data_test_buf);
  #2;            /* Delay wanted because 'data_test_buf' update delayed by #1 */
  end

end
endtask


/*----------------------------------------------------------------------------*/
// This task executes a sequence of write (STRH) operations to trigger a
// line drawing operation.

task draw_line(input [31:0] r0, r1, r2, r3, r4, r5, r6);
begin
  bus_write(R0, r0);		// abs(Larger difference)
  bus_write(R1, r1);		// abs(Smaller difference)
  bus_write(R2, r2);		// Primary step
  bus_write(R3, r3);		// Both steps
  bus_write(R4, r4);		// Address
  bus_write(R5, r5);		// Mask
  bus_write(R6, r6);		// Colour
  bus_write(GO, UNIT_LINE);	// Command
end
endtask

/*----------------------------------------------------------------------------*/
/* The given line drawing engine assumes software preprocessing               */

task pre_process_line(input [31:0] x0, y0, x1, y1, mask, colour);

reg [31:0] dx, dy, adx, ady;            // Coordinate differences & abs()
reg [31:0] sx, sy;                      // Pixel address steps
reg [31:0] m, n;                        // Larger/smaller absolute differences
reg [31:0] a1, a2;                      // Steps in major axis/both axes
reg [31:0] start_addr;                  // start address of line

begin
  dx = x1 - x0;
  dy = y1 - y0;
  if (dx[31]) begin
              sx  =  -1;
              adx = -dx;
              end
  else        begin sx = 1;
              adx = dx;
              end
  if (dy[31]) begin
              sy  = -V_WIDTH;
              ady = -dy;
              end
  else        begin
              sy  = V_WIDTH;
              ady = dy;
              end

  if (adx > ady) begin a1 = sx; m = adx; n = ady; end
  else           begin a1 = sy; m = ady; n = adx; end
  a2 = sx + sy;

  start_addr = y0 * V_WIDTH + x0;

// Text report to log file (Probably "transcript" in Questa)
$display("Values: %h %h %h %h %h %h", m, n, a1, a2, start_addr[31:0], colour);
// Now call task to output parameters
draw_line(m, n, a1, a2, start_addr, mask, colour);

end
endtask

/*----------------------------------------------------------------------------*/
/* Conway's Game of Life                                                      */

task draw_gameoflife(input [31:0] r0, r1, r2, r3, r4, r5);
begin

  bus_write(R0, r0);		// Read base
  bus_write(R1, r1);		// Write base
  bus_write(R2, r2);		// Screen width
  bus_write(R3, r3);		// Screen height
  bus_write(R4, r4);		// Alive Colour
  bus_write(R5, r5);		// Dead Colour
  bus_write(GO, UNIT_GOL);	// Command

end
endtask

/*----------------------------------------------------------------------------*/

task fs_write (input [19:0] addr, input [31:0] data);

begin
  CS_B    <= #1 1;
  read_B  <= #1 0;
  write_B <= #1 1;
  size_B  <= #1 2'h2;
  addr_B  <= #1 addr;
  dwr_B   <= #1 data;
  @ (posedge clk);
  while (stall_B) @ (posedge clk);
  write_B <= #1 0;
  CS_B    <= #1 0;
  addr_B  <= #1 20'hXXXXX;
end

endtask

/*----------------------------------------------------------------------------*/

endmodule // testbench

/******************************************************************************/