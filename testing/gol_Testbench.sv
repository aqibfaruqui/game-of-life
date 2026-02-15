/******************************************************************************/
/*                                                                            */
/* Module:   gol_Testbench                                                    */
/* Modified: December 2025                                                    */
/* Author:   A Faruqui                                                        */
/*                                                                            */
/******************************************************************************/

`timescale 1ns / 10ps

module gol_Testbench ();

`define FRAME_SIZE      1048576
`define SCREEN_WIDTH    640
`define MAX_CYCLES      100000000
`define CLOCK_PERIOD    10		
`define TPD             1

reg [7:0] golden_framestore [0 : `FRAME_SIZE - 1];
reg [7:0] sim_framestore    [0 : `FRAME_SIZE - 1];

reg pixels_drawn;

/* Host interface */
reg          clk;
reg          reset;
reg          req;
wire         ack;
wire         busy;
wire         done;

/* General arguments */
reg  [31:0]  r0;
reg  [31:0]  r1;
reg  [31:0]  r2;
reg  [31:0]  r3;
reg  [31:0]  r4;
reg  [31:0]  r5;
reg  [31:0]  r6;
reg  [31:0]  r7;

/* Framestore interface */
wire         de_req;
reg          de_ack;
wire [17:0]  de_addr;
wire  [3:0]  de_nbyte;
wire         de_rnw;
wire [31:0]  de_w_data;
reg  [31:0]  de_r_data;

/* Display interface */
reg  [17:0]  display_base;
reg   [1:0]  display_mode;
reg   [9:0]  display_height;
reg   [9:0]  display_width;


/* _ */
game_of_life gol ( .clk            (clk),
                   .reset          (reset),
                   .req            (req),
                   .ack            (ack),
                   .busy           (busy),
                   .done           (done),
                   .r0             (r0),
                   .r1             (r1),
                   .r2             (r2),
                   .r3             (r3),
                   .r4             (r4),
                   .r5             (r5),
                   .r6             (r6),
                   .r7             (r7),
                   .de_req         (de_req),
                   .de_ack         (de_ack),
                   .de_addr        (de_addr),
                   .de_nbyte       (de_nbyte),
                   .de_rnw         (de_rnw),
                   .de_w_data      (de_w_data),
                   .de_r_data      (de_r_data),
                   .display_base   (display_base),
                   .display_mode   (display_mode),
                   .display_height (display_height),
                   .display_width  (display_width) );

initial clk <= 1;
always #(`CLOCK_PERIOD/2) clk <= !clk;

initial
begin
repeat (`MAX_CYCLES) @ (posedge clk);
$stop;
end

/*----------------------------------------------------------------------------*/

string       line;
int            fd;

reg [15:0]   alive_colour;
reg [15:0]    dead_colour;
 
reg [15:0]       golden_x;
reg [15:0]       golden_y;
reg [7:0]   golden_colour;

reg [31:0]  read_base_reg;
reg [31:0] write_base_reg;
reg [31:0]      width_reg;
reg [31:0]     height_reg;

initial
begin
    static int test_count = 0;
    reg test_passed;
    int iteration_count;
    int i;

    int shape_id;
    int iterations;

    read_base_reg   <= 32'h0;
    write_base_reg  <= 32'h0;   // was 32'h12C00 for double buffering
    width_reg       <= 32'd640;
    height_reg      <= 32'd480;
    req             <= 1'b0;

    reset           <= 1'b1;
    repeat(5) @(posedge clk);
    reset           <= 1'b0;
    repeat(5) @ (posedge clk);

    fd = $fopen("models/Phase_2/golden_data.txt", "r");
    if (!fd) begin
        $error("Golden data file did not open : %0d", fd);
        $stop;
    end

    while (!$feof(fd)) begin
        // Parse START
        $fgets(line, fd);
        if ($feof(fd)) break;
        while (line == "\n") $fgets(line, fd);

        if (line != "START" && line != "START\n") begin
            if ($feof(fd)) break;   // End of golden data
            $error("Incorrect golden data format: Expected 'START'");
            $fclose(fd);
            $stop;
        end

        test_count++;
        $display("---------------------------------------------------");
        $display("Test %0d: Starting test", test_count);

        // Parse input command "alive_colour dead_colour"
        if ($fscanf (fd, "%d %d %d %d", shape_id, iterations, alive_colour, dead_colour) != 4) begin
            $error("Test %0d: Incorrect golden data format header", test_count);
            $fclose(fd);
            $stop;
        end

        $display("Test %0d: Shape: %0d | GoL Iterations: %0d | Alive Colour: %d | Dead Colour: %d", 
                  test_count, shape_id, iterations, alive_colour, dead_colour);

        // Clear golden and simulation data framestores
        for (i = 0; i < `FRAME_SIZE; i++) begin
            golden_framestore[i] = 8'h00;
            sim_framestore[i]    = 8'h00;
        end

        // Seed simulation memory
        if      (shape_id == 0) mock_line_draw(20, 20, 25, 20, alive_colour);       // Line
        else if (shape_id == 1) mock_rectangle_draw(20, 20, 21, 21, alive_colour);  // 2x2 Block
        else if (shape_id == 2) mock_rectangle_draw(20, 20, 22, 22, alive_colour);  // 3x3 Block
        else if (shape_id == 3) mock_glider_draw(20, 20, alive_colour);             // Glider
        else if (shape_id == 4) mock_line_draw(600, 400, 605, 400, alive_colour);   // Line in Corner
        else if (shape_id == 5) mock_line_draw(20, 0, 25, 0, alive_colour);         // Line at Top

        // Parse golden data and build golden framestore
        while ($fscanf (fd, "%d %d %d\n", golden_x, golden_y, golden_colour) == 3) begin
            int byte_addr; 
            byte_addr = (golden_y * `SCREEN_WIDTH) + golden_x;
            if (byte_addr < `FRAME_SIZE) begin
                golden_framestore[byte_addr] = golden_colour;
            end
        end

        // Parse END
        $fgets(line, fd);
        if (line != "END" && line != "END\n") begin
            $error("Incorrect golden data format: Expected 'END'");
            $fclose(fd);
            $stop;
        end

        // Run the DUT
        $display("Test %0d: Running Game of Life...", test_count);
        for (iteration_count = 0; iteration_count < iterations; iteration_count++) begin
             test_drawing_command(alive_colour, dead_colour);
        end

        // Comparing golden and simulation data framestores
        $display("Test %0d: Comparing framestores...", test_count);
        test_passed = 1;
        
        begin
            int err_x;
            int err_y;
            int mismatches;      // Throttle test log output for large errors
            int start_check_addr;

            mismatches = 0;
            start_check_addr = 32'h12C00 * 4;
            
            for (i = 0; i < `FRAME_SIZE; i++) begin
                if (golden_framestore[i] !== sim_framestore[i]) begin
                    test_passed = 0;
                    err_x = i % `SCREEN_WIDTH;
                    err_y = i / `SCREEN_WIDTH;
                    if (mismatches < 10) begin
                        $error("Test %0d: Mismatch at (x:%0d, y:%0d). Expected: %0d, Got: %0d", 
                                test_count, err_x, err_y, golden_framestore[i], sim_framestore[i]);
                    end
                    // & maybe break to stop after first error to avoid console spam?
                end
            end
            if (mismatches > 0) $display("Test %0d: Total Mismatches: %0d", test_count, mismatches);
        end

        if (test_passed) begin
            $display("Test %0d: Passed :)", test_count);
        end else begin
            $display("Test %0d: Failed :(", test_count);
            $stop;
        end
    end

    // Some more (non drawing related) tests
    test_count++;
    $display("---------------------------------------------------");
    $display("Test %0d: Starting test", test_count);
    test_reset(test_count);

    test_count++;
    $display("---------------------------------------------------");
    $display("Test %0d: Starting test", test_count);
    test_no_req_deassert(test_count);

    $display("All %0d tests complete :D", test_count);
    $fclose(fd);
    $stop;
end

// Independent 'thread' for pixel I/F
always @ (posedge clk) begin
	pixels_drawn <= 1'b0;
    
    if (de_req && !de_ack) begin
        int wait_cycles; 
        wait_cycles = $urandom_range(10, 1);
        repeat(wait_cycles) @(posedge clk);

        // Provide DUT data
        if (de_rnw) begin
            int base_byte;
            base_byte = de_addr * 4;
            
            de_r_data[ 7: 0] <= sim_framestore[base_byte + 0];
            de_r_data[15: 8] <= sim_framestore[base_byte + 1];
            de_r_data[23:16] <= sim_framestore[base_byte + 2];
            de_r_data[31:24] <= sim_framestore[base_byte + 3];
        end

		de_ack <= #`TPD 1'b1;
        if (!de_rnw) pixels_drawn <= 1'b1;
		@ (posedge clk)
		de_ack <= #`TPD 1'b0;
	end else if (!de_req) begin
		de_ack <= #`TPD 1'b0;
	end
end

// Independent thread to catch pixels drawn and update simulation framestore
always @(posedge clk) begin
    if (pixels_drawn) begin
        int byte_addr;
        byte_addr = de_addr * 4;

        if (de_nbyte[0] == 1'b0) sim_framestore[byte_addr + 0] <= de_w_data[7:0];
        if (de_nbyte[1] == 1'b0) sim_framestore[byte_addr + 1] <= de_w_data[15:8];
        if (de_nbyte[2] == 1'b0) sim_framestore[byte_addr + 2] <= de_w_data[23:16];
        if (de_nbyte[3] == 1'b0) sim_framestore[byte_addr + 3] <= de_w_data[31:24];
    end
end

/*----------------------------------------------------------------------------*/

task mock_line_draw(input int x0, input int y0, input int x1, input int y1, input int colour);
    int x;
    for (x = x0; x <= x1; x++) begin
        sim_framestore[y0 * `SCREEN_WIDTH + x] = colour[7:0];
    end
endtask

task mock_rectangle_draw(input int x0, input int y0, input int x1, input int y1, input int colour);
    int x, y;
    for (y = y0; y <= y1; y++) begin
        for (x = x0; x <= x1; x++) begin
            sim_framestore[y * `SCREEN_WIDTH + x] = colour[7:0];
        end
    end
endtask

task mock_glider_draw(input int start_x, input int start_y, input int colour);
    sim_framestore[(start_y + 0) * `SCREEN_WIDTH + (start_x + 1)] = colour[7:0];
    sim_framestore[(start_y + 1) * `SCREEN_WIDTH + (start_x + 2)] = colour[7:0];
    sim_framestore[(start_y + 2) * `SCREEN_WIDTH + (start_x + 0)] = colour[7:0];
    sim_framestore[(start_y + 2) * `SCREEN_WIDTH + (start_x + 1)] = colour[7:0];
    sim_framestore[(start_y + 2) * `SCREEN_WIDTH + (start_x + 2)] = colour[7:0];
endtask

// Task to run Game of Life DUT 
task test_drawing_command(input reg [15:0] alive_colour,
                          input reg [15:0] dead_colour);
begin 
    r0  <=  read_base_reg;
    r1  <=  write_base_reg;
    r2  <=  width_reg;
    r3  <=  height_reg;
    r4  <=  alive_colour;
    r5  <=  dead_colour;

    // Start from non-busy state
    @ (posedge clk);
    while (busy == 1'b1) @ (posedge clk);

    // Assert request after propagation delay
    req <= #`TPD 1'b1;

    // Wait for 'ack'
    @ (posedge clk);
    while (ack == 1'b0) @ (posedge clk);

    // De-assert (is that a word?) request
    req <= #`TPD 1'b0;

    // Spot de_ack and update some simulation framestore (in separate thread)

    // Wait for command to finish
    @ (posedge clk);
    while (busy == 1'b1) @ (posedge clk);

    // Wait a bit for signals to settle before returning
    repeat (4) @ (posedge clk);
end 
endtask

task test_reset(input int test_count);
begin
    r0  <=  0;
    r1  <=  0;
    r2  <=  640;
    r3  <=  480;
    r4  <=  255;
    r5  <=  0;
    
    // Assert request
    @(posedge clk);
    while (busy) @(posedge clk);
    req <= 1;
    @(posedge clk);
    while (!ack) @(posedge clk);
    req <= 0;
    
    // Stall until we are deep in the processing
    repeat(200) @(posedge clk);
    
    if (!busy) begin
        $warning("Test %0d: Warning DUT finished too fast!", test_count);
    end else begin
        // Assert reset while busy
        $display("Test %0d: Asserting Reset while State = %s", test_count, gol.state.name()); 
        reset <= 1;
        repeat(2) @(posedge clk);
        reset <= 0;
        
        // Check result
        @(posedge clk);
        if (busy == 1'b0 && gol.state == gol.IDLE) begin
            $display("Test %0d: Reset correctly forced to IDLE", test_count);
            $display("Test %0d: Passed :)", test_count);
        end else begin
            $display("Test %0d: Reset did not work in State %s", test_count, gol.state.name());
            $display("Test %0d: Failed :(", test_count);
        end
    end
end
endtask

task test_no_req_deassert(input int test_count);
    r0  <=  0;
    r1  <=  0;
    r2  <=  640;
    r3  <=  480;
    r4  <=  255;
    r5  <=  0;
    
    // Assert request
    @(posedge clk);
    while (busy) @(posedge clk);
    req <= 1;
    @(posedge clk);
    while (!ack) @(posedge clk);
    // Forget to deassert request!
    
    // Instead, wait for the operation to finish while holding Req high.
    $display("Test %0d: Holding request while processing...", test_count);
    wait(done);
    
    // Verify FSM is stuck in FINISH
    @(posedge clk);
    if (gol.state == gol.FINISH) begin
        $display("Test %0d: FSM correctly waiting for req to drop", test_count);
    end else begin
        $display("Test %0d: FSM moved to %s while req was still high", test_count, gol.state.name());
    end
    
    // Now drop req and verify transition to IDLE
    req <= 0;
    repeat(2) @(posedge clk);
    
    if (gol.state == gol.IDLE) begin
        $display("Test %0d: FSM returned to IDLE after req dropped", test_count);
        $display("Test %0d: Passed :)", test_count);
    end else begin
        $display("Test %0d: FSM stuck in %s", test_count, gol.state.name());
        $display("Test %0d: Failed :(", test_count);
    end
endtask

// -----------------------------------------------------------------------------

// CONCURRENT ASSERTIONS FOR COMMAND INTERFACE, assumes synchronous behaviour
// ON posedge clk, if criteria is true "|->" perform test
// ##[n] delay test by n posedge clks, ##[a:b] declares a range

assertAckOnlyOneCycleLong: assert property (@(posedge clk) (ack == 1 |-> ##1 ack == 0))
                      else $warning("Warning ack should only be one clock cycle long");

assertBusyRisesWithAck: assert property (@(posedge clk) ($rose(ack) |-> busy))
                      else $warning("Warning busy doesn't rise with ack");

assertAckImpliesReq: assert property (@(posedge clk) (ack |-> req))
                      else $warning("Warning ack rises without a valid req");

assertAckAfterReq: assert property (@(posedge clk) ($rose(req) |-> ##[1:100] $rose(ack)))
                      else $warning("Warning ack doesn't rise within 100 cycles of req");

assertDeReqHoldsUntilDeAck: assert property (@(posedge clk) (de_req && !de_ack) |-> de_req)
                      else $warning("Warning de_req drops before de_ack is received");

assertDataStable: assert property (@(posedge clk) (de_req && !de_ack) |=> $stable(de_w_data))
                      else $warning("Warning de_w_data changed while waiting for de_ack");

assertAddrStable: assert property (@(posedge clk) (de_req && !de_ack) |=> $stable(de_addr))
                      else $warning("Warning de_addr changed while waiting for de_ack");

assertAddrBounds: assert property (@(posedge clk) (de_req |-> de_addr < 'h40000))
                      else $warning("Warning output address out of bounds");

assertWriteState: assert property (@(posedge clk) ((de_req && !de_rnw) |-> (gol.state == gol.WRITE_REQ || gol.state == gol.WRITE_WAIT)))
                      else $fatal(1, "Fatal write request detected outside of WRITE_REQ/WRITE_WAIT states: FSM state is %s", gol.state.name());


endmodule

/*============================================================================*/
