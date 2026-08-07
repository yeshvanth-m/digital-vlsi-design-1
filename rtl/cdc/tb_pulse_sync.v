`timescale 1ns/1ps
// ===========================================================================
// Testbench: pulse_sync  --  single-cycle pulse across clock domains.
// Generates M spaced source pulses and confirms EXACTLY M pulses appear in the
// (slower) destination domain -- none lost, none duplicated.
// ===========================================================================
module tb_pulse_sync;
  localparam M = 6;

  reg  src_clk = 1'b0, dst_clk = 1'b0;
  reg  src_rst_n, dst_rst_n, src_pulse;
  wire dst_pulse;
  integer fail = 0, i;
  integer src_count = 0, dst_count = 0;
  reg [8*10-1:0] phase;

  pulse_sync dut (
    .src_clk(src_clk), .src_rst_n(src_rst_n), .src_pulse(src_pulse),
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .dst_pulse(dst_pulse)
  );

  always #5 src_clk = ~src_clk;   // faster source
  always #8 dst_clk = ~dst_clk;   // slower destination

  // count regenerated pulses in the destination domain
  always @(posedge dst_clk)
    if (dst_rst_n && dst_pulse) dst_count = dst_count + 1;

  initial begin
    $dumpfile("sim/pulse_sync.vcd"); $dumpvars(0, tb_pulse_sync);

    phase = "RESET";
    src_rst_n = 0; dst_rst_n = 0; src_pulse = 0;
    repeat (2) @(negedge src_clk); src_rst_n = 1;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    phase = "PULSES";
    for (i = 0; i < M; i = i + 1) begin
      @(negedge src_clk); src_pulse = 1'b1;   // one source cycle high
      @(negedge src_clk); src_pulse = 1'b0;
      src_count = src_count + 1;
      repeat (4) @(negedge src_clk);           // spacing so dst catches each edge
    end

    phase = "DRAIN";
    repeat (8) @(posedge dst_clk);             // let the last pulse cross
    $display("source pulses=%0d  destination pulses=%0d", src_count, dst_count);
    if (dst_count !== src_count) begin
      $display("FAIL: pulse count mismatch"); fail = fail + 1;
    end else $display("PASS: all pulses crossed exactly once");

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #20000; $display("FAIL: timeout"); $finish; end
endmodule
