`timescale 1ns/1ps
// ===========================================================================
// Testbench: async_fifo  --  LEVEL 3 (ADVANCED)
// ---------------------------------------------------------------------------
// Progression:
//   Level 1 (tb_async_fifo.v)              : directed, spaced, phase-labelled.
//   Level 2 (tb_async_fifo_intermediate.v) : guards + concurrency.
//   Level 3 (this file)                    : randomized coverage / stress.
//
// What makes this "advanced":
//   * RANDOM back-pressure : writer (~80%) and reader (~60%) each drop their
//     enable at random, so full/empty come and go organically.
//   * TRUE concurrency     : writer and reader run in a fork/join on their own
//     (unequal) clocks at the same time.
//   * MANY WRAPS           : N = 300 transfers wraps the 8-bit data pattern and
//     the pointers ~37 times, exercising the Gray-code MSB wrap repeatedly.
//   * SCOREBOARD           : data is an incrementing sequence, so the k-th word
//     read MUST equal k (mod 256) -- this catches any loss, duplication, or
//     reordering across the clock-domain crossing.
//   * COVERAGE ASSERTIONS  : the run is required to actually observe BOTH full
//     and empty, otherwise it fails (a passing test that never filled/emptied
//     the FIFO proves nothing).
//
// Run:
//   iverilog -o sim/async_fifo_l3.vvp rtl/memories/async_fifo.v rtl/memories/tb_async_fifo_advanced.v
//   vvp sim/async_fifo_l3.vvp
//   surfer sim/async_fifo_l3.vcd
// ===========================================================================

module tb_async_fifo_advanced;
  localparam DW = 8;
  localparam AW = 3;
  localparam N  = 300;            // total words streamed through the FIFO

  reg           wr_clk = 1'b0;
  reg           rd_clk = 1'b0;
  reg           wr_rst_n, rd_rst_n;
  reg           wr_en, rd_en;
  reg  [DW-1:0] din;
  wire [DW-1:0] dout;
  wire          full, empty;

  integer fail_count = 0;
  integer wk, rk;                 // accepted-write / accepted-read counters
  reg [DW-1:0] wseq, rseq;        // producer / expected sequences
  reg          full_seen  = 1'b0; // coverage flags
  reg          empty_seen = 1'b0;

  reg [8*10-1:0] phase;           // ASCII narration -- view as String/ASCII

  async_fifo #(.DW(DW), .AW(AW)) dut (
    .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .din(din), .full(full),
    .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en), .dout(dout), .empty(empty)
  );

  // Unequal clocks; write faster than read (so the FIFO tends to fill).
  always #10 wr_clk = ~wr_clk;    // 50 MHz
  always #17 rd_clk = ~rd_clk;    // ~29 MHz

  // Coverage: latch whenever full/empty are actually seen.
  always @(posedge wr_clk) if (full)  full_seen  <= 1'b1;
  always @(posedge rd_clk) if (empty) empty_seen <= 1'b1;

  initial begin
    $dumpfile("sim/async_fifo_l3.vcd");
    $dumpvars(0, tb_async_fifo_advanced);

    phase = "RESET";
    wr_rst_n = 0; rd_rst_n = 0; wr_en = 0; rd_en = 0; din = 0;
    wseq = 8'h00; rseq = 8'h00;
    repeat (2) @(negedge wr_clk);
    wr_rst_n = 1; rd_rst_n = 1;
    repeat (2) @(negedge wr_clk);

    phase = "STREAM";
    fork
      // -------- randomized producer: N accepted writes --------------------
      begin : PROD
        wk = 0;
        while (wk < N) begin
          @(negedge wr_clk);
          if (!full && (({$random} % 10) < 8)) begin
            din = wseq; wr_en = 1'b1;        // din set on negedge (no race)
          end else begin
            wr_en = 1'b0;
          end
          @(posedge wr_clk);                 // accepted iff wr_en (full stable)
          if (wr_en && !full) begin
            wseq = wseq + 1'b1;
            wk   = wk + 1;
          end
        end
        @(negedge wr_clk); wr_en = 1'b0;
      end

      // -------- randomized consumer: N accepted reads, scoreboarded -------
      begin : CONS
        wait (full);                         // let it fill first (covers full)
        rk = 0;
        while (rk < N) begin
          @(negedge rd_clk);
          if (!empty && (({$random} % 10) < 6)) rd_en = 1'b1;
          else                                  rd_en = 1'b0;
          @(posedge rd_clk);                 // pop iff rd_en (empty stable)
          if (rd_en && !empty) begin
            @(negedge rd_clk);               // dout now stable
            if (dout !== rseq) begin
              $display("FAIL: read %0d dout=%h expected=%h (t=%0t)",
                       rk, dout, rseq, $time);
              fail_count = fail_count + 1;
            end
            rseq  = rseq + 1'b1;
            rk    = rk + 1;
            rd_en = 1'b0;
          end
        end
      end
    join

    phase = "DONE";
    repeat (3) @(negedge rd_clk);

    // ---- coverage: the stimulus must have actually stressed both flags ----
    if (!full_seen) begin
      $display("FAIL: coverage -- FULL never observed");
      fail_count = fail_count + 1;
    end
    if (!empty_seen) begin
      $display("FAIL: coverage -- EMPTY never observed");
      fail_count = fail_count + 1;
    end

    $display("---------------------------");
    $display("streamed %0d words | full_seen=%b empty_seen=%b | failures=%0d",
             N, full_seen, empty_seen, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("SOME TESTS FAILED");
    $display("---------------------------");
    #100 $finish;
  end

  initial begin
    #500000;
    $display("FAIL: timeout -- wrote %0d read %0d of %0d", wk, rk, N);
    $finish;
  end

endmodule
