`timescale 1ns/1ps
// ===========================================================================
// Testbench: async_fifo  --  LEVEL 2 (INTERMEDIATE)
// ---------------------------------------------------------------------------
// Progression:
//   Level 1 (tb_async_fifo.v)              : directed, spaced, phase-labelled.
//   Level 2 (this file)                    : + guards + concurrency.
//   Level 3 (tb_async_fifo_advanced.v)     : randomized coverage.
//
// New scenarios shown here that Level 1 did NOT cover:
//   * UNDERFLOW guard : read while EMPTY must be ignored (rptr must not move).
//   * OVERFLOW guard  : write while FULL must be ignored (wptr must not move,
//                       and the poison data must never appear on the output).
//   * CONCURRENT R+W  : both clocks drive wr_en and rd_en at the SAME time
//                       (the defining async-FIFO case), checked for order.
//
// A `phase` ASCII string narrates the waveform (view as String/ASCII).
//
// Run:
//   iverilog -o sim/async_fifo_l2.vvp rtl/memories/async_fifo.v rtl/memories/tb_async_fifo_intermediate.v
//   vvp sim/async_fifo_l2.vvp
//   surfer sim/async_fifo_l2.vcd
// ===========================================================================

module tb_async_fifo_intermediate;
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
  integer wk, rk;                 // per-process loop counters (concurrent phase)
  reg [DW-1:0] wseq, rseq;        // concurrent-phase data sequences
  reg [AW:0]   ptr_snap;          // pointer snapshot for guard checks

  reg [8*10-1:0] phase;           // ASCII narration -- view as String/ASCII

  async_fifo #(.DW(DW), .AW(AW)) dut (
    .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .din(din), .full(full),
    .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en), .dout(dout), .empty(empty)
  );

  always #10 wr_clk = ~wr_clk;    // 50 MHz
  always #15 rd_clk = ~rd_clk;    // ~33 MHz

  task check(input cond, input [8*24-1:0] name);
    begin
      if (!cond) begin
        $display("FAIL: %0s (t=%0t)", name, $time);
        fail_count = fail_count + 1;
      end else begin
        $display("PASS: %0s (t=%0t)", name, $time);
      end
    end
  endtask

  // one write (din on negedge -> sampled on posedge, no race)
  task push(input [DW-1:0] data); begin
    @(negedge wr_clk);
    while (full) @(negedge wr_clk);
    din = data; wr_en = 1'b1;
    @(posedge wr_clk);
    @(negedge wr_clk);
    wr_en = 1'b0;
  end endtask

  // one read + ordering check (waits for data)
  task pop_check(input [DW-1:0] exp); begin
    @(negedge rd_clk);
    while (empty) @(negedge rd_clk);
    rd_en = 1'b1;
    @(posedge rd_clk);
    @(negedge rd_clk);
    rd_en = 1'b0;
    check(dout === exp, "read data/order");
  end endtask

  initial begin
    $dumpfile("sim/async_fifo_l2.vcd");
    $dumpvars(0, tb_async_fifo_intermediate);

    phase = "RESET";
    wr_rst_n = 0; rd_rst_n = 0; wr_en = 0; rd_en = 0; din = 0;
    wseq = 8'h50; rseq = 8'h50;
    repeat (2) @(negedge rd_clk);
    wr_rst_n = 1; rd_rst_n = 1;
    repeat (3) @(negedge rd_clk);

    // ---- UNDERFLOW: read while empty must be ignored ----------------------
    phase = "UNDERFLOW";
    check(empty === 1'b1, "empty after reset");
    ptr_snap = dut.rbin;
    @(negedge rd_clk); rd_en = 1'b1;   // try to read an empty FIFO
    @(posedge rd_clk);
    @(posedge rd_clk);
    @(negedge rd_clk); rd_en = 1'b0;
    check(empty === 1'b1,          "empty still set on underflow");
    check(dut.rbin === ptr_snap,   "rptr frozen on underflow");
    repeat (3) @(negedge rd_clk);

    // ---- fill exactly to FULL with a known pattern ------------------------
    phase = "FILL FULL";
    for (i = 0; i < DEPTH; i = i + 1)
      push(8'h20 + i[DW-1:0]);         // 0x20..0x27
    repeat (2) @(negedge wr_clk);
    check(full === 1'b1, "full after DEPTH writes");

    // ---- OVERFLOW: write while full must be ignored -----------------------
    phase = "OVERFLOW";
    ptr_snap = dut.wbin;
    @(negedge wr_clk); din = 8'hEE; wr_en = 1'b1;  // poison, should be dropped
    @(posedge wr_clk);
    @(negedge wr_clk); din = 8'hEF;                // second poison
    @(posedge wr_clk);
    @(negedge wr_clk); wr_en = 1'b0;
    check(full === 1'b1,          "full held during overflow");
    check(dut.wbin === ptr_snap,  "wptr frozen on overflow");

    // ---- drain: must see 0x20..0x27 in order, NO poison -------------------
    phase = "DRAIN";
    for (i = 0; i < DEPTH; i = i + 1)
      pop_check(8'h20 + i[DW-1:0]);
    check(empty === 1'b1, "empty after full drain");
    repeat (3) @(negedge rd_clk);

    // ---- CONCURRENT read + write (both enables active together) -----------
    phase = "CONCURRENT";
    fork
      // writer: 16 accepted writes of an incrementing sequence
      begin : WRITER
        wk = 0;
        while (wk < 16) begin
          @(negedge wr_clk);
          if (!full) begin din = wseq; wr_en = 1'b1; end
          else            wr_en = 1'b0;
          @(posedge wr_clk);
          if (wr_en && !full) begin wseq = wseq + 1'b1; wk = wk + 1; end
        end
        @(negedge wr_clk); wr_en = 1'b0;
      end
      // reader: 16 accepted reads, checked in order
      begin : READER
        rk = 0;
        while (rk < 16) begin
          @(negedge rd_clk);
          if (!empty) rd_en = 1'b1;
          else        rd_en = 1'b0;
          @(posedge rd_clk);
          if (rd_en && !empty) begin
            @(negedge rd_clk);              // dout stable
            check(dout === rseq, "concurrent order");
            rseq = rseq + 1'b1; rk = rk + 1;
            rd_en = 1'b0;
          end
        end
      end
    join

    phase = "DONE";
    repeat (3) @(negedge rd_clk);
    $display("---------------------------");
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("%0d FAILURES", fail_count);
    $display("---------------------------");
    #100 $finish;
  end

  initial begin
    #60000;
    $display("FAIL: timeout");
    $finish;
  end

endmodule
