`timescale 1ns/1ps
// ===========================================================================
// Testbench: pulse_stretch_sync  --  fast source pulse -> slow destination.
// Fires NP single-cycle pulses in the fast domain (spaced apart) and checks
// each one is recovered as exactly one pulse in the slower destination domain.
// ===========================================================================
module tb_pulse_stretch_sync;
  localparam NP = 5;

  reg  src_clk = 1'b0, src_rst_n;
  reg  dst_clk = 1'b0, dst_rst_n;
  reg  src_pulse;
  wire dst_pulse;

  integer sent = 0, recv = 0, fail = 0, i;
  reg [8*10-1:0] phase;

  pulse_stretch_sync #(.STRETCH(3)) dut (
    .src_clk(src_clk), .src_rst_n(src_rst_n), .src_pulse(src_pulse),
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .dst_pulse(dst_pulse)
  );

  always #4 src_clk = ~src_clk;    // fast source
  always #13 dst_clk = ~dst_clk;   // much slower destination

  always @(posedge dst_clk)
    if (dst_rst_n && dst_pulse) recv = recv + 1;

  task check(input cond, input [8*32-1:0] name); begin
    if (!cond) begin $display("FAIL: %0s (t=%0t)", name, $time); fail = fail + 1; end
    else            $display("PASS: %0s (t=%0t)", name, $time);
  end endtask

  initial begin
    $dumpfile("sim/pulse_stretch_sync.vcd"); $dumpvars(0, tb_pulse_stretch_sync);

    phase = "RESET"; src_rst_n = 0; dst_rst_n = 0; src_pulse = 0;
    repeat (2) @(negedge src_clk); src_rst_n = 1;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    // one-cycle source pulses, spaced so stretched levels do not merge
    phase = "PULSES";
    for (i = 0; i < NP; i = i + 1) begin
      @(negedge src_clk); src_pulse = 1'b1;
      @(negedge src_clk); src_pulse = 1'b0;
      sent = sent + 1;
      repeat (10) @(negedge src_clk);   // gap > stretch + sync latency
    end

    phase = "DRAIN"; repeat (10) @(posedge dst_clk);

    check(recv == sent, "one dst pulse per source pulse");
    $display("sent=%0d  recovered=%0d", sent, recv);

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #12000; $display("FAIL: timeout"); $finish; end
endmodule
