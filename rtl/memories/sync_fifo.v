// ===========================================================================
// sync_fifo.v  --  synchronous (single-clock) FIFO, parameterized.
// ---------------------------------------------------------------------------
// Storage = simple dual-port RAM; control = read/write pointers + flags.
// The pointers carry ONE EXTRA MSB above the address bits: this is the classic
// trick to distinguish FULL from EMPTY when the low bits are equal.
//   empty : wptr == rptr
//   full  : MSBs differ AND low (address) bits are equal
// For a CROSS-CLOCK (async) FIFO you would Gray-code the pointers and pass them
// through 2-FF synchronizers before comparing.
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat sync_fifo "rtl/memories/sync_fifo.v" "rtl/memories/tb_sync_fifo.v"
// Outputs: sim\sync_fifo.*   build\sync_fifo_gates.*   build\sync_fifo_sky130.*
// ===========================================================================
`timescale 1ns/1ps

module sync_fifo #(
  parameter DW = 8,          // data width
  parameter AW = 3           // address width -> depth = 2**AW
) (
  input  wire          clk,
  input  wire          rst_n,   // active-low synchronous reset
  input  wire          wr_en,
  input  wire          rd_en,
  input  wire [DW-1:0] din,
  output reg  [DW-1:0] dout,
  output wire          full,
  output wire          empty
);

  reg [DW-1:0] mem [0:(1<<AW)-1];
  reg [AW:0]   wptr, rptr;      // one extra MSB for full/empty disambiguation

  // ---- write side ----
  always @(posedge clk)
    if (!rst_n)
      wptr <= 0;
    else if (wr_en && !full) begin
      mem[wptr[AW-1:0]] <= din;
      wptr <= wptr + 1'b1;
    end

  // ---- read side ----
  always @(posedge clk)
    if (!rst_n)
      rptr <= 0;
    else if (rd_en && !empty) begin
      dout <= mem[rptr[AW-1:0]];
      rptr <= rptr + 1'b1;
    end

  // ---- flags ----
  assign empty = (wptr == rptr);
  assign full  = (wptr[AW]     != rptr[AW]) &&
                 (wptr[AW-1:0] == rptr[AW-1:0]);

endmodule
