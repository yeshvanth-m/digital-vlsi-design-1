`timescale 1ns/1ps
// ===========================================================================
// Testbench: toggle_sync  --  reusable toggle synchronizer primitive.
// A source domain flips src_toggle once per "event" (well spaced). The dest
// must reproduce exactly one dst_change strobe per flip and track dst_level.
// ===========================================================================
module tb_toggle_sync;
  localparam EVENTS = 6;

  reg  src_clk = 1'b0, src_rst_n;
  reg  dst_clk = 1'b0, dst_rst_n;
  reg  src_toggle;
  wire dst_level, dst_change;

  integer src_events = 0;   // flips generated in the source domain
  integer dst_events = 0;   // strobes recovered in the destination domain
  integer fail = 0, i;
  reg [8*10-1:0] phase;

  toggle_sync #(.STAGES(2)) dut (
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n),
    .src_toggle(src_toggle), .dst_level(dst_level), .dst_change(dst_change)
  );

  always #6 src_clk = ~src_clk;   // faster source
  always #9 dst_clk = ~dst_clk;   // slower destination

  // count recovered events in the destination domain
  always @(posedge dst_clk)
    if (dst_rst_n && dst_change) dst_events = dst_events + 1;

  task check(input cond, input [8*32-1:0] name); begin
    if (!cond) begin $display("FAIL: %0s (t=%0t)", name, $time); fail = fail + 1; end
    else            $display("PASS: %0s (t=%0t)", name, $time);
  end endtask

  initial begin
    $dumpfile("sim/toggle_sync.vcd"); $dumpvars(0, tb_toggle_sync);

    phase = "RESET"; src_rst_n = 0; dst_rst_n = 0; src_toggle = 0;
    repeat (2) @(negedge src_clk); src_rst_n = 1;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    // generate EVENTS spaced flips in the source domain
    phase = "EVENTS";
    for (i = 0; i < EVENTS; i = i + 1) begin
      @(negedge src_clk); src_toggle = ~src_toggle; src_events = src_events + 1;
      repeat (4) @(negedge src_clk);   // spacing > sync latency
    end

    phase = "DRAIN"; repeat (8) @(posedge dst_clk);

    check(dst_level === src_toggle, "dst_level tracks source toggle");
    check(dst_events == src_events, "one dst pulse per source flip");
    $display("src flips=%0d  dst pulses=%0d", src_events, dst_events);

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #8000; $display("FAIL: timeout"); $finish; end
endmodule
