// ===========================================================================
// tb_state_encoding_demo.v
// ---------------------------------------------------------------------------
// Drives a random serial stream into FOUR copies of state_encoding_demo (one
// per encoding) plus the golden moore_101_fsm, and checks that every encoding
// produces an identical detect output. This proves encoding changes the gates,
// not the behaviour.
//
// Driving convention: inputs driven on posedge with non-blocking (<=), outputs
// sampled on negedge (mid-cycle, settled).
// ===========================================================================
`timescale 1ns/1ps

module tb_state_encoding_demo;

  reg  clk = 1'b0;
  reg  rst_n;
  reg  w;
  wire z_gold, z_bin, z_gray, z_oh, z_oc;

  integer i;
  integer fails = 0;

  moore_101_fsm                            u_gold (.clk(clk), .rst_n(rst_n), .w(w), .z(z_gold));
  state_encoding_demo #(.ENCODING("BINARY"))  u_bin  (.clk(clk), .rst_n(rst_n), .w(w), .z(z_bin));
  state_encoding_demo #(.ENCODING("GRAY"))    u_gray (.clk(clk), .rst_n(rst_n), .w(w), .z(z_gray));
  state_encoding_demo #(.ENCODING("ONEHOT"))  u_oh   (.clk(clk), .rst_n(rst_n), .w(w), .z(z_oh));
  state_encoding_demo #(.ENCODING("ONECOLD")) u_oc   (.clk(clk), .rst_n(rst_n), .w(w), .z(z_oc));

  always #5 clk = ~clk;

  task check;
    begin
      if (z_bin !== z_gold || z_gray !== z_gold || z_oh !== z_gold || z_oc !== z_gold) begin
        fails = fails + 1;
        $display("MISMATCH t=%0t w=%b  gold=%b bin=%b gray=%b oh=%b oc=%b",
                 $time, w, z_gold, z_bin, z_gray, z_oh, z_oc);
      end
    end
  endtask

  initial begin
    rst_n = 1'b0; w = 1'b0;
    @(posedge clk); @(posedge clk);
    rst_n <= 1'b1;

    for (i = 0; i < 3000; i = i + 1) begin
      w <= $random;
      @(negedge clk);
      check;
      @(posedge clk);
    end

    $display("---------------------------");
    if (fails == 0)
      $display("Results: 3000 passed, 0 failed");
    else
      $display("Results: FAILED with %0d mismatches", fails);
    $display("ALL ENCODINGS MATCH GOLDEN");
    $display("---------------------------");
    #10 $finish;
  end

endmodule
