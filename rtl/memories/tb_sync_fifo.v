`timescale 1ns/1ps
// ===========================================================================
// Testbench: sync_fifo  (single-clock FIFO, depth 8)
// 1) Fill the FIFO (8 writes) and confirm FULL asserts; a 9th write is ignored.
// 2) Drain the FIFO (8 reads) and confirm data comes out in order (FIFO) and
//    that EMPTY asserts at the end.
//
// Convention: drive DUT inputs on the posedge with a non-blocking <= (matches
// tb_counter.v / tb_mealy_101_fsm.v); sample flags/data mid-cycle on the
// negedge where everything is stable.
//
// Run:
//   iverilog -o sim/sync_fifo.vvp rtl/memories/sync_fifo.v rtl/memories/tb_sync_fifo.v
//   vvp sim/sync_fifo.vvp
//   gtkwave sim/sync_fifo.vcd
// ===========================================================================

module tb_sync_fifo;
  localparam DW = 8;
  localparam AW = 3;
  localparam DEPTH = (1 << AW);

  reg           clk = 1'b0;
  reg           rst_n;
  reg           wr_en, rd_en;
  reg  [DW-1:0] din;
  wire [DW-1:0] dout;
  wire          full, empty;

  integer i;
  integer pass_count = 0, fail_count = 0;

  sync_fifo #(.DW(DW), .AW(AW)) dut (
    .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en),
    .din(din), .dout(dout), .full(full), .empty(empty)
  );

  always #5 clk = ~clk;

  task expect_flag;
    input         got;
    input         exp;
    input [127:0] name;
    begin
      if (got !== exp) begin
        $display("FAIL: %0s = %b, expected %b (t=%0t)", name, got, exp, $time);
        fail_count = fail_count + 1;
      end else begin
        pass_count = pass_count + 1;
      end
    end
  endtask

  initial begin
    $dumpfile("sim/sync_fifo.vcd");
    $dumpvars(0, tb_sync_fifo);

    rst_n = 1'b0; wr_en = 1'b0; rd_en = 1'b0; din = 0;
    @(posedge clk);
    @(posedge clk);
    rst_n <= 1'b1;
    @(negedge clk);
    expect_flag(empty, 1'b1, "empty@reset");
    expect_flag(full,  1'b0, "full@reset");

    // ---- fill phase: 8 writes, din = 0x10 + i ----
    @(posedge clk);
    for (i = 0; i < DEPTH; i = i + 1) begin
      wr_en <= 1'b1;
      din   <= 8'h10 + i[DW-1:0];
      @(posedge clk);          // this edge pushes din
    end
    wr_en <= 1'b0;
    @(negedge clk);
    expect_flag(full,  1'b1, "full@8writes");
    expect_flag(empty, 1'b0, "empty@8writes");

    // ---- overflow guard: 9th write must be ignored ----
    @(posedge clk);
    wr_en <= 1'b1; din <= 8'hFF;
    @(posedge clk);
    wr_en <= 1'b0;
    @(negedge clk);
    expect_flag(full, 1'b1, "full@overflow");

    // ---- drain phase: 8 reads, expect 0x10..0x17 in order ----
    @(posedge clk);
    rd_en <= 1'b1;
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge clk);          // this edge pops -> dout updates
      @(negedge clk);          // sample dout mid-cycle
      if (dout !== (8'h10 + i[DW-1:0])) begin
        $display("FAIL: read %0d dout=%h expected=%h (t=%0t)",
                 i, dout, 8'h10 + i, $time);
        fail_count = fail_count + 1;
      end else begin
        pass_count = pass_count + 1;
      end
      $display("read %0d dout=%h", i, dout);
    end
    rd_en <= 1'b0;
    @(negedge clk);
    expect_flag(empty, 1'b1, "empty@drained");
    expect_flag(full,  1'b0, "full@drained");

    $display("---------------------------");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0) $display("ALL TESTS PASSED");
    else                 $display("SOME TESTS FAILED");
    $display("---------------------------");
    #10 $finish;
  end

endmodule
