`timescale 1ns/1ps
// ===========================================================================
// Testbench: regfile  (2R/1W register file, async read)
// Writes a known pattern to every location, then reads all locations back on
// BOTH read ports and checks the data.
//
// Convention (matches tb_counter.v / tb_mealy_101_fsm.v): drive DUT inputs on
// the posedge with a non-blocking <=. The DUT samples the old value at that
// edge while the new value lands in the NBA region, so there is no same-edge
// race. Combinational outputs are sampled mid-cycle on the negedge.
//
// Run:
//   iverilog -o sim/regfile.vvp rtl/memories/regfile.v rtl/memories/tb_regfile.v
//   vvp sim/regfile.vvp
//   gtkwave sim/regfile.vcd
// ===========================================================================

module tb_regfile;
  localparam DW = 8;
  localparam AW = 4;
  localparam DEPTH = (1 << AW);

  reg           clk = 1'b0;
  reg           we;
  reg  [AW-1:0] wa, ra0, ra1;
  reg  [DW-1:0] wd;
  wire [DW-1:0] rd0, rd1;

  integer i;
  integer pass_count = 0, fail_count = 0;

  reg [DW-1:0] expected [0:DEPTH-1];

  regfile #(.DW(DW), .AW(AW)) dut (
    .clk(clk), .we(we), .wa(wa), .ra0(ra0), .ra1(ra1),
    .wd(wd), .rd0(rd0), .rd1(rd1)
  );

  always #5 clk = ~clk;

  task check;
    input [AW-1:0] addr;
    input [DW-1:0] got;
    input          port;
    begin
      if (got !== expected[addr]) begin
        $display("FAIL: port%0d addr=%0d got=%h expected=%h (t=%0t)",
                 port, addr, got, expected[addr], $time);
        fail_count = fail_count + 1;
      end else begin
        pass_count = pass_count + 1;
      end
    end
  endtask

  initial begin
    $dumpfile("sim/regfile.vcd");
    $dumpvars(0, tb_regfile);

    we = 1'b0; wa = 0; ra0 = 0; ra1 = 0; wd = 0;
    @(posedge clk);

    // ---- write phase: mem[i] = i ^ 8'hA5 (driven on posedge with <=) ----
    for (i = 0; i < DEPTH; i = i + 1) begin
      we <= 1'b1;
      wa <= i[AW-1:0];
      wd <= i[DW-1:0] ^ 8'hA5;
      expected[i] = i[DW-1:0] ^ 8'hA5;
      @(posedge clk);          // this edge commits mem[i]
    end
    we <= 1'b0;
    @(posedge clk);

    // ---- read phase: read back on both ports (async / combinational) ----
    for (i = 0; i < DEPTH; i = i + 1) begin
      ra0 <= i[AW-1:0];
      ra1 <= (DEPTH-1-i);      // reverse order on port 1
      @(negedge clk);          // sample mid-cycle, addresses stable
      check(ra0, rd0, 0);
      check(ra1, rd1, 1);
      $display("addr0=%0d rd0=%h | addr1=%0d rd1=%h", ra0, rd0, ra1, rd1);
    end

    $display("---------------------------");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("SOME TESTS FAILED");
    $display("---------------------------");
    #10 $finish;
  end

endmodule
