`timescale 1ns/1ps
// ===========================================================================
// Testbench: rom  (synchronous ROM initialized from rom_init.hex)
// rom_init.hex holds i*i (mod 256) for i = 0..15. The TB walks every address
// (1-cycle read latency) and checks dout against the recomputed square.
//
// Run (from C:\digital-design-tools so the $readmemh path resolves):
//   iverilog -o sim/rom.vvp rtl/memories/rom.v rtl/memories/tb_rom.v
//   vvp sim/rom.vvp
//   gtkwave sim/rom.vcd
// ===========================================================================

module tb_rom;
  localparam DW = 8;
  localparam AW = 4;
  localparam DEPTH = (1 << AW);

  reg           clk = 1'b0;
  reg  [AW-1:0] addr;
  wire [DW-1:0] dout;

  integer i;
  integer pass_count = 0, fail_count = 0;
  reg [DW-1:0] exp;

  rom #(.DW(DW), .AW(AW), .INIT_FILE("rtl/memories/rom_init.hex")) dut (
    .clk(clk), .addr(addr), .dout(dout)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("sim/rom.vcd");
    $dumpvars(0, tb_rom);

    addr = 0;
    @(posedge clk);

    for (i = 0; i < DEPTH; i = i + 1) begin
      addr = i[AW-1:0];
      @(posedge clk);          // latch mem[addr] into dout
      #1;
      exp = (i*i);             // expected square (mod 256)
      if (dout !== exp) begin
        $display("FAIL: addr=%0d dout=%h expected=%h (t=%0t)",
                 i, dout, exp, $time);
        fail_count = fail_count + 1;
      end else begin
        pass_count = pass_count + 1;
      end
      $display("addr=%2d dout=%h (%0d)", i, dout, dout);
    end

    $display("---------------------------");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("SOME TESTS FAILED");
    $display("---------------------------");
    #10 $finish;
  end

endmodule
