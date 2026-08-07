`timescale 1ns/1ps
// ===========================================================================
// Testbench: async_fifo  (dual-clock FIFO, depth 8)  --  LEVEL 1 (BASIC / DEMO)
//
// Graded teaching series (same DUT, increasing difficulty):
//   Level 1 (this file)                    : directed, spaced, phase-labelled.
//   Level 2 (tb_async_fifo_intermediate.v) : underflow/overflow guards + concurrency.
//   Level 3 (tb_async_fifo_advanced.v)     : randomized concurrent stress + coverage.
//
// This TB is written to produce a READABLE waveform for the classroom, not a
// stress test. Operations are DIRECTED and SPACED OUT with idle gaps so each
// event stands on its own:
//   1) single write  ->  gap  ->  single read      (see the CDC latency gap)
//   2) two writes    ->  gap  ->  two reads         (see FIFO ordering)
//   3) fill to FULL  ->  drain to EMPTY            (see the full/empty flags)
//
// A `phase` signal carries a short ASCII string ("WRITE A1", "GAP", "READ A1"
// ...). Display it as text in the viewer to narrate the waveform:
//   * Surfer   : right-click the `phase` signal -> Format -> ASCII (String)
//   * GTKWave  : right-click -> Data Format -> ASCII
//
// Clocking discipline: inputs are driven on each clock's NEGEDGE (stable well
// before the DUT samples them on the POSEDGE), so there is no read/write race.
// The read task WAITS for !empty, which is exactly where the write->read clock
// crossing latency shows up as a visible gap.
//
// Run:
//   iverilog -o sim/async_fifo.vvp rtl/memories/async_fifo.v rtl/memories/tb_async_fifo.v
//   vvp sim/async_fifo.vvp
//   surfer sim/async_fifo.vcd      (or: gtkwave sim/async_fifo.vcd)
// ===========================================================================

module tb_async_fifo;
  localparam DW = 8;
  localparam AW = 3;
  localparam DEPTH = (1 << AW);

  reg           wr_clk = 1'b0;
  reg           rd_clk = 1'b0;
  reg           wr_rst_n, rd_rst_n;
  reg           wr_en, rd_en;
  reg  [DW-1:0] din;
  wire [DW-1:0] dout;
  wire          full, empty;

  integer fail_count = 0;
  integer i;

  // ASCII narration label -- view as String/ASCII in the waveform viewer.
  reg [8*10-1:0] phase;

  async_fifo #(.DW(DW), .AW(AW)) dut (
    .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .din(din), .full(full),
    .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en), .dout(dout), .empty(empty)
  );

  // Slow, clearly-different clocks so each cycle is wide on screen.
  always #10 wr_clk = ~wr_clk;   // 50 MHz  (period 20 ns)
  always #15 rd_clk = ~rd_clk;   // ~33 MHz (period 30 ns)

  // ---- idle helpers: hold the bus quiet for a visible gap ------------------
  task wr_idle(input integer n); begin
    for (i = 0; i < n; i = i + 1) @(negedge wr_clk);
  end endtask
  task rd_idle(input integer n); begin
    for (i = 0; i < n; i = i + 1) @(negedge rd_clk);
  end endtask

  // ---- one write: din driven on the negedge, accepted on the next posedge --
  task push(input [DW-1:0] data); begin
    @(negedge wr_clk);
    while (full) @(negedge wr_clk);   // wait for room (won't happen in this demo)
    din   = data;
    wr_en = 1'b1;
    @(posedge wr_clk);                // <-- word is written here
    @(negedge wr_clk);
    wr_en = 1'b0;
  end endtask

  // ---- one read: wait for !empty (this is where CDC latency is visible) ----
  task pop_check(input [DW-1:0] exp); begin
    @(negedge rd_clk);
    while (empty) @(negedge rd_clk);  // <-- gap: write pointer crossing to rd
    rd_en = 1'b1;
    @(posedge rd_clk);                // <-- pop; dout registers next
    @(negedge rd_clk);                // dout now stable
    rd_en = 1'b0;
    if (dout !== exp) begin
      $display("FAIL: dout=%h expected=%h (t=%0t)", dout, exp, $time);
      fail_count = fail_count + 1;
    end else begin
      $display("PASS: read %h  (t=%0t)", dout, $time);
    end
  end endtask

  // -------------------------------------------------------------------------
  // Directed teaching scenario.
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("sim/async_fifo.vcd");
    $dumpvars(0, tb_async_fifo);

    phase = "RESET";
    wr_rst_n = 1'b0; rd_rst_n = 1'b0;
    wr_en = 1'b0; rd_en = 1'b0; din = 8'h00;
    rd_idle(2);
    wr_rst_n = 1'b1; rd_rst_n = 1'b1;

    phase = "IDLE";
    rd_idle(3);

    // ---- 1) single write, GAP, single read --------------------------------
    phase = "WRITE A1";
    push(8'hA1);
    phase = "GAP";
    rd_idle(4);                 // explicit breathing room between 1W and 1R
    phase = "READ A1";
    pop_check(8'hA1);

    phase = "IDLE";
    rd_idle(4);

    // ---- 2) two writes, GAP, two reads (shows FIFO order) ------------------
    phase = "WRITE B0";
    push(8'hB0);
    phase = "WRITE B1";
    push(8'hB1);
    phase = "GAP";
    rd_idle(4);
    phase = "READ B0";
    pop_check(8'hB0);
    phase = "READ B1";
    pop_check(8'hB1);

    phase = "IDLE";
    rd_idle(4);

    // ---- 3) fill to FULL, then drain to EMPTY (shows the flags) -----------
    phase = "FILL FULL";
    for (i = 0; i < DEPTH; i = i + 1)
      push(8'hC0 + i[DW-1:0]);   // C0..C7 -> FIFO becomes full
    rd_idle(2);                  // let full/empty settle for the screenshot

    phase = "DRAIN";
    for (i = 0; i < DEPTH; i = i + 1)
      pop_check(8'hC0 + i[DW-1:0]);

    phase = "DONE";
    rd_idle(3);
    $display("---------------------------");
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("%0d FAILURES", fail_count);
    $display("---------------------------");
    #100 $finish;
  end

  // Timeout safety net so a broken CDC can't hang the sim forever.
  initial begin
    #50000;
    $display("FAIL: timeout");
    $finish;
  end

endmodule
