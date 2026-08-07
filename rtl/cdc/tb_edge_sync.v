`timescale 1ns/1ps
// ===========================================================================
// Testbench: edge_sync  --  edge synchronizer / edge-detector types.
// One source-domain level (a rise then a fall) feeds three instances:
//   rising-only  -> 1 strobe   falling-only -> 1 strobe   both -> 2 strobes.
// Proves the synchronized level and the selected edge detection are correct.
// ===========================================================================
module tb_edge_sync;
  reg  dst_clk = 1'b0, dst_rst_n;
  reg  async_in;

  wire lvl_r, edge_r;   // rising
  wire lvl_f, edge_f;   // falling
  wire lvl_b, edge_b;   // both

  integer n_r = 0, n_f = 0, n_b = 0, fail = 0;
  reg [8*10-1:0] phase;

  edge_sync #(.STAGES(2), .EDGE(0)) dut_r (
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .async_in(async_in),
    .dst_level(lvl_r), .dst_edge(edge_r));
  edge_sync #(.STAGES(2), .EDGE(1)) dut_f (
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .async_in(async_in),
    .dst_level(lvl_f), .dst_edge(edge_f));
  edge_sync #(.STAGES(2), .EDGE(2)) dut_b (
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n), .async_in(async_in),
    .dst_level(lvl_b), .dst_edge(edge_b));

  always #5 dst_clk = ~dst_clk;

  always @(posedge dst_clk) if (dst_rst_n) begin
    if (edge_r) n_r = n_r + 1;
    if (edge_f) n_f = n_f + 1;
    if (edge_b) n_b = n_b + 1;
  end

  task check(input cond, input [8*32-1:0] name); begin
    if (!cond) begin $display("FAIL: %0s (t=%0t)", name, $time); fail = fail + 1; end
    else            $display("PASS: %0s (t=%0t)", name, $time);
  end endtask

  initial begin
    $dumpfile("sim/edge_sync.vcd"); $dumpvars(0, tb_edge_sync);

    phase = "RESET"; dst_rst_n = 0; async_in = 0;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    phase = "RISE";  @(negedge dst_clk); async_in = 1'b1;
    repeat (6) @(posedge dst_clk);
    check(lvl_r === 1'b1, "level synchronized high");

    phase = "FALL";  @(negedge dst_clk); async_in = 1'b0;
    repeat (6) @(posedge dst_clk);
    check(lvl_r === 1'b0, "level synchronized low");

    phase = "CHECK";
    check(n_r == 1, "rising type: 1 strobe");
    check(n_f == 1, "falling type: 1 strobe");
    check(n_b == 2, "both type: 2 strobes");
    $display("edges  rising=%0d falling=%0d both=%0d", n_r, n_f, n_b);

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #5000; $display("FAIL: timeout"); $finish; end
endmodule
