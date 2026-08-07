`timescale 1ns/1ps
// ===========================================================================
// Testbench: handshake_sync  --  multi-bit data across clocks via req/ack.
// Sends NW words from the source; a destination monitor checks each word is
// received once, in order (via the dst_valid strobe).
// ===========================================================================
module tb_handshake_sync;
  localparam DW = 8;
  localparam NW = 4;

  reg           src_clk = 1'b0, dst_clk = 1'b0;
  reg           src_rst_n, dst_rst_n;
  reg           src_valid;
  reg  [DW-1:0] src_data;
  wire          src_ready;
  wire          dst_valid;
  wire [DW-1:0] dst_data;
  integer fail = 0, i, rx = 0;
  reg [8*10-1:0] phase;

  handshake_sync #(.DW(DW)) dut (
    .src_clk(src_clk), .src_rst_n(src_rst_n),
    .src_valid(src_valid), .src_data(src_data), .src_ready(src_ready),
    .dst_clk(dst_clk), .dst_rst_n(dst_rst_n),
    .dst_valid(dst_valid), .dst_data(dst_data)
  );

  always #5 src_clk = ~src_clk;   // faster source
  always #9 dst_clk = ~dst_clk;   // slower destination

  // destination monitor: check received data value and order
  always @(posedge dst_clk)
    if (dst_rst_n && dst_valid) begin
      if (dst_data !== (8'hA0 + rx[DW-1:0])) begin
        $display("FAIL: rx %0d got %h expected %h (t=%0t)",
                 rx, dst_data, 8'hA0 + rx, $time);
        fail = fail + 1;
      end else
        $display("PASS: rx %0d = %h (t=%0t)", rx, dst_data, $time);
      rx = rx + 1;
    end

  initial begin
    $dumpfile("sim/handshake_sync.vcd"); $dumpvars(0, tb_handshake_sync);

    phase = "RESET";
    src_rst_n = 0; dst_rst_n = 0; src_valid = 0; src_data = 0;
    repeat (2) @(negedge src_clk); src_rst_n = 1;
    repeat (2) @(negedge dst_clk); dst_rst_n = 1;

    phase = "SEND";
    for (i = 0; i < NW; i = i + 1) begin
      @(negedge src_clk);
      while (!src_ready) @(negedge src_clk);   // wait for the channel
      src_data  = 8'hA0 + i[DW-1:0];
      src_valid = 1'b1;
      @(negedge src_clk);
      src_valid = 1'b0;                        // one-cycle request
      @(negedge src_clk);
      while (src_ready) @(negedge src_clk);    // ensure transfer started
    end

    phase = "WAIT";
    wait (rx == NW);

    phase = "DONE"; repeat (4) @(posedge dst_clk);
    $display("---------------------------");
    if (fail == 0 && rx == NW) $display("ALL TESTS PASSED");
    else                       $display("%0d FAILURES (rx=%0d)", fail, rx);
    $display("---------------------------");
    #10 $finish;
  end

  initial begin #30000; $display("FAIL: timeout (rx=%0d)", rx); $finish; end
endmodule
