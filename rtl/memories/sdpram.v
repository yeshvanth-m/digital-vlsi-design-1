// ===========================================================================
// sdpram.v  --  simple dual-port RAM (parameterized).
// ---------------------------------------------------------------------------
// One dedicated WRITE port (waddr/din/we) and one dedicated READ port (raddr).
// Both share a single clock here. This is the classic building block of a FIFO
// and of line buffers. Registered read -> block-RAM friendly.
// For a TRUE dual-port (2 independent R/W ports, possibly 2 clocks) you would
// add a second write path and a second clock.
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat sdpram "rtl/memories/sdpram.v" "rtl/memories/tb_sdpram.v"
// Outputs: sim\sdpram.*   build\sdpram_gates.*   build\sdpram_sky130.*
// ===========================================================================
`timescale 1ns/1ps

module sdpram #(
  parameter DW = 8,          // data width
  parameter AW = 4           // address width -> depth = 2**AW
) (
  input  wire          clk,
  input  wire          we,     // write-port enable
  input  wire [AW-1:0] waddr,  // write address
  input  wire [AW-1:0] raddr,  // read address (independent of waddr)
  input  wire [DW-1:0] din,    // write data
  output reg  [DW-1:0] dout    // registered read data
);

  reg [DW-1:0] mem [0:(1<<AW)-1];

  always @(posedge clk) begin
    if (we) mem[waddr] <= din;  // write port
    dout <= mem[raddr];         // read port (separate address)
  end

endmodule
