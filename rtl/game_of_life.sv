/******************************************************************************/
/*                                                                            */
/*  Module:   Conway's Game of Life (2D Cellular Automata)                    */
/*  Modified: November 2025                                                   */
/*  Author:   Aqib Faruqui                                                    */
/*                                                                            */
/*  Description:                                                              */
/*  Single iteration of 'Conway's Game of Life' with inputs for               */
/*  alive/dead colours                                                        */
/*                                                                            */
/******************************************************************************/

`timescale 1ns / 10ps 

module game_of_life( input  logic        clk,
                     input  logic        reset,
                     input  logic        req,             /* Interface to command */
                     output logic        ack,
     
                     input  logic [31:0] r0,              /*  General arguments   */
                     input  logic [31:0] r1,
                     input  logic [31:0] r2,
                     input  logic [31:0] r3,
                     input  logic [31:0] r4,
                     input  logic [31:0] r5,
                     input  logic [31:0] r6,
                     input  logic [31:0] r7,
                     output logic        busy,            /*    Status outputs    */
                     output logic        done,
     
                     output logic        de_req,          /* Framestore interface */
                     input  logic        de_ack,
                     output logic [17:0] de_addr,
                     output logic  [3:0] de_nbyte,
                     output logic        de_rnw,
                     output logic [31:0] de_w_data,
                     input  logic [31:0] de_r_data,
     
                     input  logic [17:0] display_base,    /* Display status info. */
                     input  logic  [1:0] display_mode,    /*  *May* be used for   */
                     input  logic  [9:0] display_height,  /*  added flexibility.  */
                     input  logic  [9:0] display_width );


localparam TPD = 1;                      /* Define a "local parameter"        */


/************************************************/
/*                 FSM States                   */
/************************************************/
typedef enum logic [3:0] {
    IDLE,               // 0: Waiting for a request
    ACK,                // 1: Acknowledge request, latch arguments
    PRIME_READ_REQ,     // 2: Request 1st/2nd row data
    PRIME_READ_WAIT,    // 3: Wait for framestore ack
    PRIME_READ_LATCH,   // 4: Latch 32-bit word, store 4 bits
    MAIN_READ_REQ,      // 5: Request data for row (y+2)
    MAIN_READ_WAIT,     // 6: Wait for framestore ack
    MAIN_READ_LATCH,    // 7: Latch 32-bit word, store 4 bits
    COMPUTE,            // 8: Compute 1 pixel, buffer for writing
    WRITE_REQ,          // 9: Write 32-bit (4 pixel) word
    WRITE_WAIT,         // 10: Wait for framestore ack
    ROW_DONE,           // 11: Rotate buffers, increment y
    FINISH              // 12: Job complete, assert 'done'
} state_t;

state_t state, next_state;


/************************************************/
/*                  Registers                   */
/************************************************/
logic [  9:0] width_reg, height_reg;
logic [  7:0] alive_colour_reg, dead_colour_reg;
logic [ 17:0] read_base_reg, write_base_reg;

logic [  9:0] x_read, x_compute;    // X-coordinate counters
logic [  9:0] y_read, y_compute;    // Y-coordinate counters
logic [641:0] row_buffer [0:2];     // 3-row buffer, 642 bits wide (for 0-padding on left/right)
logic [ 31:0] write_word_buf;       // 4-pixel output buffer
logic [  1:0] write_lane;           // derived from x_compute
logic [ 31:0] read_data_captured;   // latch for reading framestore 

logic ack_reg, busy_reg, done_reg;
logic de_req_reg, de_rnw_reg;
logic [17:0] de_addr_reg, write_addr_reg;


/************************************************/
/*               Output Assigns                 */
/************************************************/
assign ack       = ack_reg;
assign busy      = busy_reg;
assign done      = done_reg;
assign de_req    = de_req_reg;
assign de_rnw    = de_rnw_reg;
assign de_addr   = de_addr_reg;
assign de_w_data = write_word_buf;
assign de_nbyte  = 4'b0000; // Always R/W full 32-bit words


/************************************************/
/*              Game Of Life Logic              */
/************************************************/
logic [ 3:0] neighbour_count;
logic        current_state_bit, next_state_bit;
logic [ 7:0] new_pixel_colour;
logic [ 9:0] x_pixel;

assign x_pixel = (x_compute > 0) ? x_compute - 1 : 0; // x_compute starts at 1 (to account for left padding at index 0)

assign neighbour_count = row_buffer[0][x_compute - 1] + row_buffer[0][x_compute] + row_buffer[0][x_compute + 1] +
                         row_buffer[1][x_compute - 1] + 0                        + row_buffer[1][x_compute + 1] +
                         row_buffer[2][x_compute - 1] + row_buffer[2][x_compute] + row_buffer[2][x_compute + 1];

assign current_state_bit = row_buffer[1][x_compute];

assign next_state_bit    = (neighbour_count == 3) | 
                           (current_state_bit & (neighbour_count == 2));

assign new_pixel_colour  = next_state_bit ? alive_colour_reg : dead_colour_reg;


/************************************************/
/*                 Address Logic                */
/************************************************/
assign write_lane = x_pixel[1:0];

// Note: Address is a 32-bit word address
// (y * (width / 4)) + (x / 4)
wire [17:0] read_addr;
wire [17:0] write_addr;

assign read_addr  = read_base_reg  + (y_read    * (width_reg >> 2)) + (x_read  >> 2);
assign write_addr = write_base_reg + (y_compute * (width_reg >> 2)) + (x_pixel >> 2);


/************************************************/
/*            FSM Combinatorial Logic           */
/************************************************/
always_comb begin
    next_state    = state;
    ack_reg       = 1'b0;
    busy_reg      = (state != IDLE || req);
    done_reg      = 1'b0;
    de_req_reg    = 1'b0;
    de_rnw_reg    = 1'b0;
    de_addr_reg   = 18'h0;
    
    case (state)
        IDLE: begin
            if (req) begin
                next_state = ACK;
            end
        end
        
        ACK: begin
            ack_reg    = 1'b1;
            next_state = PRIME_READ_REQ;
        end
        
        // Priming: Read Row 0 into buf[1], Row 1 into buf[2]
        PRIME_READ_REQ: begin
            de_req_reg  = 1'b1;
            de_rnw_reg  = 1'b1;         // Read
            de_addr_reg = read_addr;    // y_read = 0 or 1
            
            if (de_ack) begin
                next_state = PRIME_READ_WAIT;
            end
        end
        
        // Hold req=1 until ack=1, then wait 1 cycle for stable/captured data
        PRIME_READ_WAIT: begin
            next_state = PRIME_READ_LATCH;
        end
        
        PRIME_READ_LATCH: begin
            // Increment x_read logic in sequential block
            if (x_read + 4 < width_reg) begin
                next_state = PRIME_READ_REQ;
            end 
            else begin // Finished a row
                if (y_read == 0) begin
                    next_state = PRIME_READ_REQ;    // Go read 2nd priming row
                end else begin
                    next_state = COMPUTE;           // Priming done (Rows 0 & 1 loaded)
                end
            end
        end

        // Main Loop: Compute for row Y, then rotate rows i.e. drop row Y-1, read in row Y+2
        MAIN_READ_REQ: begin
            if (y_read < height_reg) begin
                // Read next row into free buffer [0]
                de_req_reg  = 1'b1;
                de_rnw_reg  = 1'b1;
                de_addr_reg = read_addr;
                if (de_ack) begin
                    next_state = MAIN_READ_WAIT;
                end
            end 
            else begin
                // No more rows to read (at bottom border)
                // Compute last row with an empty buffer below it
                next_state = COMPUTE;
            end
        end
        
        // Hold req=1 until ack=1, then wait 1 cycle for data
        MAIN_READ_WAIT: begin
            next_state = MAIN_READ_LATCH;
        end
        
        MAIN_READ_LATCH: begin
            if (x_read + 4 < width_reg) begin       // Filling buffer word by word
                next_state = MAIN_READ_REQ;
            end else begin
                // Row read is complete
                next_state = COMPUTE;
            end
        end
        
        COMPUTE: begin
            // Includes implicit check for x_pixel >= width_reg as width_reg is divisible by 4
            if (write_lane == 2'b11) begin
                next_state = WRITE_REQ;
            end
            // else: stay in COMPUTE, increment x_compute
        end
        
        WRITE_REQ: begin
            de_req_reg  = 1'b1;         // Make request
            de_rnw_reg  = 1'b0;         // Write
            de_addr_reg = write_addr_reg;
            next_state = WRITE_WAIT;
        end
        
        WRITE_WAIT: begin
            de_req_reg  = 1'b1;
            de_rnw_reg  = 1'b0;
            de_addr_reg = write_addr_reg;
            if (de_ack) next_state = (x_compute + 1 >= width_reg) ? ROW_DONE : COMPUTE;
        end
        
        ROW_DONE: begin
            // Check if we just computed the last row (height - 1)
            next_state = (y_compute + 1 >= height_reg) ? FINISH : MAIN_READ_REQ;
        end
        
        FINISH: begin
            done_reg = 1'b1;
            if (!req) begin
                next_state = IDLE;
            end
        end

        default: next_state = IDLE;
    endcase
end


/************************************************/
/*             FSM Sequential Logic             */
/************************************************/
always_ff @(posedge clk) begin
    read_data_captured <= de_r_data;

    if (reset) begin
        state <= IDLE;
        row_buffer[0]     <= 0;
        row_buffer[1]     <= 0;
        row_buffer[2]     <= 0;
        x_read            <= 0; 
        y_read            <= 0;
        x_compute         <= 0; 
        y_compute         <= 0;
        write_word_buf    <= 0;
        write_addr_reg    <= 0;
        
    end else begin
        state <= next_state;
        
        case(state)
            ACK: begin
                read_base_reg    <= r0[17:0];
                write_base_reg   <= r1[17:0];
                width_reg        <= r2[9:0];
                height_reg       <= r3[9:0];
                alive_colour_reg <= r4[7:0];
                dead_colour_reg  <= r5[7:0];

                x_read          <= 0;
                y_read          <= 0;
                x_compute       <= 1;       // Start at 1 for padding
                y_compute       <= 0;
                
                // Clear buffers for new run
                write_word_buf  <= 32'h0;
                row_buffer[0]   <= 0;
                row_buffer[1]   <= 0;
                row_buffer[2]   <= 0;
            end
            
            PRIME_READ_LATCH: begin
                logic [3:0] bits;
                bits[0] = (read_data_captured[ 7: 0] == alive_colour_reg);
                bits[1] = (read_data_captured[15: 8] == alive_colour_reg);
                bits[2] = (read_data_captured[23:16] == alive_colour_reg);
                bits[3] = (read_data_captured[31:24] == alive_colour_reg);
                
                // Store 4 bits into correct buffer
                // We use x_read+1..x_read+4 for 642-bit padding
                // Leave buffer[0] filled with 0s
                row_buffer[y_read + 1][x_read + 1 +: 4] <= bits;
                
                // Increment read x or move to next row
                if (x_read + 4 >= width_reg) begin
                    x_read <= 0;
                    y_read <= y_read + 1;
                end else begin
                    x_read <= x_read + 4;
                end
            end

            MAIN_READ_LATCH: begin
                logic [3:0] bits;
                bits[0] = (read_data_captured[ 7: 0] == alive_colour_reg);
                bits[1] = (read_data_captured[15: 8] == alive_colour_reg);
                bits[2] = (read_data_captured[23:16] == alive_colour_reg);
                bits[3] = (read_data_captured[31:24] == alive_colour_reg);
                
                // Store 4 bits into correct buffer
                // We use x_read+1..x_read+4 for 642-bit padding
                // Leave buffer[0] filled with 0s
                row_buffer[2][x_read + 1 +: 4] <= bits;
                
                // Increment read x or move to next row
                if (x_read + 4 >= width_reg) begin
                    x_read <= 0;
                    y_read <= y_read + 1;
                end else begin
                    x_read <= x_read + 4;
                end
            end

            COMPUTE: begin
                // Shift in the new pixel color into the write buffer
                write_word_buf[write_lane * 8 +: 8] <= new_pixel_colour;
                x_compute <= x_compute + 1;
                
                // Includes implicit check for x_pixel >= width_reg as width_reg is divisible by 4
                if (write_lane == 2'b11) begin
                    write_addr_reg <= write_addr;
                end
            end

            WRITE_WAIT: begin
                // Clear write buffer after successful write
                if (x_pixel >= width_reg - 1) begin
                    write_word_buf <= 0;
                end
            end

            ROW_DONE: begin
                // Rotate buffers up
                row_buffer[0] <= row_buffer[1];
                row_buffer[1] <= row_buffer[2];
                row_buffer[2] <= 0;             // Clear row buffer for next read

                // Reset X, increment Y
                x_compute <= 1; // Start at 1 for padding
                y_compute <= y_compute + 1;
                write_word_buf <= 0;
            end
        endcase
    end
end

endmodule
