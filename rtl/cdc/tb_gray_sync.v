`timescale 1ns/1ps
// ===========================================================================
// Testbench: gray_sync  --  multi-bit counter crossing via Gray code.
// Increments the source counter N times and checks the destination copy is
// MONOTONIC (never jumps backward or overshoots -- i.e. never a bogus value)
// and finally catches the source count.
// ===========================================================================
module tb_gray_sync;
  localparam W = 4;
  localparam N = 10;

  reg          src_clk = 1'b0, dst_clk = 1'b0;
  reg          src_rst_n, dst_rst_n, incr;
  wire [W-1:0] src_bin, dst_bin;
  integer fail = 0, i;
  reg [W-1:0] prev;
  reg [8*10-1:0] phase;

  gray_sync #(.W(W)) dut (
    .src_clk(src_clk), .src_rst_n(src_rst_n), .incr(incr), .src_bin(src_bin),
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .dst_bin(dst_bin)
  );

  always #7 src_clk = ~src_clk;   // slower source
  always #5 dst_clk = ~dst_clk;   // faster destination (catches every value)

  // monotonic / no-overshoot monitor in the destination domain
  always @(posedge dst_clk)
    if (dst_rst_n) begin
      if (dst_bin < prev)  begin $display("FAIL: non-monotonic %0d<%0d (t=%0t)", dst_bin, prev, $time); fail = fail + 1; end
      if (dst_bin > N)     begin $display("FAIL: overshoot %0d (t=%0t)", dst_bin, $time); fail = fail + 1; end
      prev <= dst_bin;
    end

  initial begin
    $dumpfile("sim/gray_sync.vcd"); $dumpvars(0, tb_gray_sync);

    phase = "RESET";
    src_rst_n = 0; dst_rst_n = 0; incr = 0; prev = 0;
    repeat (2) @(negedge src_clk); src_rst_n = 1;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    phase = "COUNT";
    for (i = 0; i < N; i = i + 1) begin
      @(negedge src_clk); incr = 1'b1;
      @(negedge src_clk); incr = 1'b0;
      repeat (3) @(negedge src_clk);           // spacing so dst catches each value
    end

    phase = "SETTLE";
    repeat (10) @(posedge dst_clk);
    if (src_bin !== N[W-1:0]) begin $display("FAIL: src=%0d expected %0d", src_bin, N); fail = fail + 1; end
    else                          $display("PASS: source counted to %0d", src_bin);
    if (dst_bin !== N[W-1:0]) begin $display("FAIL: dst=%0d expected %0d", dst_bin, N); fail = fail + 1; end
    else                          $display("PASS: destination caught %0d", dst_bin);

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #20000; $display("FAIL: timeout"); $finish; end
endmodule
