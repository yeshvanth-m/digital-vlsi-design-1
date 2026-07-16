`timescale 1ns/1ps
// ===========================================================================
// Testbench: sdpram  (simple dual-port RAM)
// Fill the RAM through the write port, then stream it out through the read
// port (1-cycle read latency).
//
// Convention: drive DUT inputs on the posedge with a non-blocking <= (matches
// tb_counter.v / tb_mealy_101_fsm.v); sample the registered output after the
// capturing posedge.
//
// Run:
//   iverilog -o sim/sdpram.vvp rtl/memories/sdpram.v rtl/memories/tb_sdpram.v
//   vvp sim/sdpram.vvp
//   gtkwave sim/sdpram.vcd
// ===========================================================================

module tb_sdpram;
  localparam DW = 8;
  localparam AW = 4;
  localparam DEPTH = (1 << AW);

  reg           clk = 1'b0;
  reg           we;
  reg  [AW-1:0] waddr, raddr;
  reg  [DW-1:0] din;
  wire [DW-1:0] dout;

  integer i;
  integer pass_count = 0, fail_count = 0;
  reg [DW-1:0] expected [0:DEPTH-1];

  sdpram #(.DW(DW), .AW(AW)) dut (
    .clk(clk), .we(we), .waddr(waddr), .raddr(raddr), .din(din), .dout(dout)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("sim/sdpram.vcd");
    $dumpvars(0, tb_sdpram);

    we = 1'b0; waddr = 0; raddr = 0; din = 0;
    @(posedge clk);

    // ---- fill through the write port: mem[i] = i*3 + 1 ----
    for (i = 0; i < DEPTH; i = i + 1) begin
      we    <= 1'b1;
      waddr <= i[AW-1:0];
      din   <= (i*3 + 1);
      expected[i] = (i*3 + 1);
      @(posedge clk);          // this edge commits mem[i]
    end
    we <= 1'b0;

    // ---- drain through the read port (registered read) ----
    for (i = 0; i < DEPTH; i = i + 1) begin
      raddr <= i[AW-1:0];
      @(posedge clk);          // this edge latches mem[raddr] into dout
      @(negedge clk);          // sample dout mid-cycle
      if (dout !== expected[i]) begin
        $display("FAIL: raddr=%0d dout=%h expected=%h (t=%0t)",
                 i, dout, expected[i], $time);
        fail_count = fail_count + 1;
      end else begin
        pass_count = pass_count + 1;
      end
      $display("raddr=%0d dout=%h", i, dout);
    end

    $display("---------------------------");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("SOME TESTS FAILED");
    $display("---------------------------");
    #10 $finish;
  end

endmodule
