`timescale 1ns/1ps
// ===========================================================================
// Testbench: nff_sync  --  N-flop level synchronizer (here STAGES = 3).
// Proves the destination sees the level exactly STAGES clocks after it changes,
// i.e. adding stages adds latency (the MTBF-vs-latency trade-off, in cycles).
// ===========================================================================
module tb_nff_sync;
  localparam STAGES = 3;

  reg  dst_clk = 1'b0;
  reg  dst_rst_n;
  reg  din;
  wire dout;
  integer fail = 0, s;
  reg [8*10-1:0] phase;

  nff_sync #(.STAGES(STAGES)) dut (
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .din(din), .dout(dout)
  );

  always #5 dst_clk = ~dst_clk;

  task check(input cond, input [8*32-1:0] name); begin
    if (!cond) begin $display("FAIL: %0s (t=%0t)", name, $time); fail = fail + 1; end
    else            $display("PASS: %0s (t=%0t)", name, $time);
  end endtask

  initial begin
    $dumpfile("sim/nff_sync.vcd"); $dumpvars(0, tb_nff_sync);

    phase = "RESET"; dst_rst_n = 1'b0; din = 1'b0;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1'b1;
    check(dout === 1'b0, "low after reset");

    // rising level -> must take exactly STAGES clocks
    phase = "RISE"; @(negedge dst_clk); din = 1'b1;
    for (s = 0; s < STAGES; s = s + 1) begin
      @(posedge dst_clk); #1;
      if (s < STAGES-1) check(dout === 1'b0, "not yet (still in the chain)");
    end
    check(dout === 1'b1, "1 seen after STAGES=3 clocks");

    // falling level -> same latency
    phase = "FALL"; @(negedge dst_clk); din = 1'b0;
    for (s = 0; s < STAGES; s = s + 1) begin
      @(posedge dst_clk); #1;
      if (s < STAGES-1) check(dout === 1'b1, "still high in the chain");
    end
    check(dout === 1'b0, "0 seen after STAGES=3 clocks");

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #5000; $display("FAIL: timeout"); $finish; end
endmodule
