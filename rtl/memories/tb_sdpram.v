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
  // Explicit memory taps so waveform viewers always show array contents.
  wire [DW-1:0] mem_dbg00 = dut.mem[0];
  wire [DW-1:0] mem_dbg01 = dut.mem[1];
  wire [DW-1:0] mem_dbg02 = dut.mem[2];
  wire [DW-1:0] mem_dbg03 = dut.mem[3];
  wire [DW-1:0] mem_dbg04 = dut.mem[4];
  wire [DW-1:0] mem_dbg05 = dut.mem[5];
  wire [DW-1:0] mem_dbg06 = dut.mem[6];
  wire [DW-1:0] mem_dbg07 = dut.mem[7];
  wire [DW-1:0] mem_dbg08 = dut.mem[8];
  wire [DW-1:0] mem_dbg09 = dut.mem[9];
  wire [DW-1:0] mem_dbg10 = dut.mem[10];
  wire [DW-1:0] mem_dbg11 = dut.mem[11];
  wire [DW-1:0] mem_dbg12 = dut.mem[12];
  wire [DW-1:0] mem_dbg13 = dut.mem[13];
  wire [DW-1:0] mem_dbg14 = dut.mem[14];
  wire [DW-1:0] mem_dbg15 = dut.mem[15];

  sdpram #(.DW(DW), .AW(AW)) dut (
    .clk(clk), .we(we), .waddr(waddr), .raddr(raddr), .din(din), .dout(dout)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("sim/sdpram.vcd");
    $dumpvars(0, tb_sdpram);
    $dumpvars(0, mem_dbg00, mem_dbg01, mem_dbg02, mem_dbg03,
                 mem_dbg04, mem_dbg05, mem_dbg06, mem_dbg07,
                 mem_dbg08, mem_dbg09, mem_dbg10, mem_dbg11,
                 mem_dbg12, mem_dbg13, mem_dbg14, mem_dbg15);

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
