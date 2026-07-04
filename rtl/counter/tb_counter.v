// ===========================================================================
// tb_counter.v  --  testbench for counter.v
// Checks that tc == (count == 15) every cycle and dumps a VCD.
// ===========================================================================
`timescale 1ns/1ps

module tb_counter;

  reg        clk = 1'b0;
  reg        rst_n;
  wire [3:0] count;
  wire       tc;

  integer    i;
  integer    fails = 0;

  counter dut (.clk(clk), .rst_n(rst_n), .count(count), .tc(tc));

  always #5 clk = ~clk;

  initial begin
    $dumpfile("sim/counter.vcd");
    $dumpvars(0, tb_counter);

    rst_n = 1'b0;
    @(posedge clk); @(posedge clk);
    rst_n <= 1'b1;

    for (i = 0; i < 20; i = i + 1) begin
      @(negedge clk);
      if (tc !== (count == 4'd15)) begin
        fails = fails + 1;
        $display("MISMATCH  count=%2d  tc=%b", count, tc);
      end
      $display("count=%2d  tc=%b", count, tc);
    end

    $display("---------------------------");
    if (fails == 0) $display("Results: 20 passed, 0 failed  (tc tracks count==15)");
    else            $display("Results: FAILED with %0d mismatches", fails);
    $display("---------------------------");
    #10 $finish;
  end

endmodule
