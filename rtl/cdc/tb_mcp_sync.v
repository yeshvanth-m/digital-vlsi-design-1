`timescale 1ns/1ps
// ===========================================================================
// Testbench: mcp_sync  --  2-phase (MCP) multi-bit data synchronizer.
// Sends NW words from the source, honoring src_busy, and checks the
// destination captures every word exactly once and in order (via dst_valid).
// ===========================================================================
module tb_mcp_sync;
  localparam DW = 8;
  localparam NW = 5;

  reg           src_clk = 1'b0, src_rst_n;
  reg           dst_clk = 1'b0, dst_rst_n;
  reg           src_load;
  reg  [DW-1:0] src_data;
  wire          src_busy;
  wire          dst_valid;
  wire [DW-1:0] dst_data;

  integer got = 0, fail = 0, i;
  reg [DW-1:0] expect_q [0:NW-1];
  reg [8*10-1:0] phase;

  mcp_sync #(.DW(DW)) dut (
    .src_clk(src_clk), .src_rst_n(src_rst_n),
    .src_load(src_load), .src_data(src_data), .src_busy(src_busy),
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n),
    .dst_valid(dst_valid), .dst_data(dst_data)
  );

  always #5 src_clk = ~src_clk;
  always #8 dst_clk = ~dst_clk;   // slower destination

  // destination monitor: check each captured word against the queue, in order
  always @(posedge dst_clk)
    if (dst_rst_n && dst_valid) begin
      if (got < NW) begin
        if (dst_data === expect_q[got])
          $display("PASS: word %0d = 0x%02h", got, dst_data);
        else begin
          $display("FAIL: word %0d got 0x%02h exp 0x%02h", got, dst_data, expect_q[got]);
          fail = fail + 1;
        end
      end
      got = got + 1;
    end

  // send one word, waiting for the link to be free first
  task send(input [DW-1:0] d); begin
    @(negedge src_clk); while (src_busy) @(negedge src_clk);
    src_data = d; src_load = 1'b1;
    @(negedge src_clk); src_load = 1'b0;
  end endtask

  initial begin
    $dumpfile("sim/mcp_sync.vcd"); $dumpvars(0, tb_mcp_sync);

    phase = "RESET"; src_rst_n = 0; dst_rst_n = 0; src_load = 0; src_data = 0;
    repeat (2) @(negedge src_clk); src_rst_n = 1;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    phase = "SEND";
    for (i = 0; i < NW; i = i + 1) begin
      expect_q[i] = 8'hA0 + i[7:0];
      send(8'hA0 + i[7:0]);
    end

    phase = "DRAIN"; repeat (12) @(posedge dst_clk);

    if (got != NW) begin $display("FAIL: got %0d of %0d words", got, NW); fail = fail + 1; end
    else $display("PASS: all %0d words received", NW);

    phase = "DONE"; #20;
    $display("---------------------------");
    if (fail == 0) $display("ALL TESTS PASSED"); else $display("%0d FAILURES", fail);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #12000; $display("FAIL: timeout"); $finish; end
endmodule
