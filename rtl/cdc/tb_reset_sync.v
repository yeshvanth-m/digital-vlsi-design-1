`timescale 1ns/1ps
// ===========================================================================
// Testbench: reset_sync  --  async assert, synchronous de-assert.
// Shows: (1) reset forces the output low immediately (async), (2) release only
// takes effect STAGES clock edges later (synchronous), (3) a later re-assert is
// again immediate. `phase` narrates the waveform (view as ASCII/String).
// ===========================================================================
module tb_reset_sync;
  localparam STAGES = 2;

  reg  clk = 1'b0;
  reg  async_rst_n;
  wire sync_rst_n;
  integer fail = 0, s;
  reg [8*10-1:0] phase;

  reset_sync #(.STAGES(STAGES)) dut (
    .clk(clk), .async_rst_n(async_rst_n), .sync_rst_n(sync_rst_n)
  );

  always #5 clk = ~clk;

  task check(input cond, input [8*28-1:0] name); begin
    if (!cond) begin $display("FAIL: %0s (t=%0t)", name, $time); fail = fail + 1; end
    else            $display("PASS: %0s (t=%0t)", name, $time);
  end endtask

  initial begin
    $dumpfile("sim/reset_sync.vcd"); $dumpvars(0, tb_reset_sync);

    phase = "ASSERT"; async_rst_n = 1'b0;
    #12; check(sync_rst_n === 1'b0, "async assert forces low");

    // release asynchronously, between two clock edges
    @(negedge clk); #2; async_rst_n = 1'b1; phase = "RELEASE";
    for (s = 0; s < STAGES; s = s + 1) begin
      @(posedge clk); #1;
      if (s < STAGES-1) check(sync_rst_n === 1'b0, "still held mid-release");
    end
    check(sync_rst_n === 1'b1, "released after STAGES clocks");

    // async re-assert must not wait for a clock
    @(posedge clk); #2; phase = "REASSERT"; async_rst_n = 1'b0; #1;
    check(sync_rst_n === 1'b0, "async re-assert immediate");

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #5000; $display("FAIL: timeout"); $finish; end
endmodule
