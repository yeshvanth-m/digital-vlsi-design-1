`timescale 1ns/1ps
// ===========================================================================
// Testbench: spram  (single-port RAM, synchronous/registered read)
// Phase 1: write mem[i] = ~i to all locations.
// Phase 2: read each location back (1-cycle read latency) and check.
//
// Convention: drive DUT inputs on the posedge with a non-blocking <= (matches
// tb_counter.v / tb_mealy_101_fsm.v); sample the registered output after the
// capturing posedge.
//
// Run:
//   iverilog -o sim/spram.vvp rtl/memories/spram.v rtl/memories/tb_spram.v
//   vvp sim/spram.vvp
//   gtkwave sim/spram.vcd
// ===========================================================================

module tb_spram;
  localparam DW = 8;
  localparam AW = 4;
  localparam DEPTH = (1 << AW);

  reg           clk = 1'b0;
  reg           we;
  reg  [AW-1:0] addr;
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

  spram #(.DW(DW), .AW(AW)) dut (
    .clk(clk), .we(we), .addr(addr), .din(din), .dout(dout)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("sim/spram.vcd");
    $dumpvars(0, tb_spram);
    $dumpvars(0, mem_dbg00, mem_dbg01, mem_dbg02, mem_dbg03,
                 mem_dbg04, mem_dbg05, mem_dbg06, mem_dbg07,
                 mem_dbg08, mem_dbg09, mem_dbg10, mem_dbg11,
                 mem_dbg12, mem_dbg13, mem_dbg14, mem_dbg15);

    we = 1'b0; addr = 0; din = 0;
    @(posedge clk);

    // ---- write phase (driven on posedge with <=) ----
    for (i = 0; i < DEPTH; i = i + 1) begin
      we   <= 1'b1;
      addr <= i[AW-1:0];
      din  <= ~i[DW-1:0];
      expected[i] = ~i[DW-1:0];
      @(posedge clk);          // this edge commits mem[i]
    end
    we <= 1'b0;

    // ---- read phase (registered read -> data valid one cycle later) ----
    for (i = 0; i < DEPTH; i = i + 1) begin
      addr <= i[AW-1:0];
      @(posedge clk);          // this edge latches mem[addr] into dout
      @(negedge clk);          // sample dout mid-cycle
      if (dout !== expected[i]) begin
        $display("FAIL: addr=%0d dout=%h expected=%h (t=%0t)",
                 i, dout, expected[i], $time);
        fail_count = fail_count + 1;
      end else begin
        pass_count = pass_count + 1;
      end
      $display("addr=%0d dout=%h", i, dout);
    end

    $display("---------------------------");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("SOME TESTS FAILED");
    $display("---------------------------");
    #10 $finish;
  end

endmodule
