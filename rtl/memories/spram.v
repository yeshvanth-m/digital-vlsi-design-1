// ===========================================================================
// spram.v  --  single-port RAM (parameterized), synchronous read.
// ---------------------------------------------------------------------------
// One shared address for read AND write. The REGISTERED read (dout <= mem[..])
// is what lets synthesis map this to BLOCK RAM. As written this is READ-FIRST
// (old data appears on dout the same cycle as a write to the same address).
// Swap the two statements in the always block for WRITE-FIRST behavior.
// NOTE: the array is intentionally NOT reset (reset the output reg instead).
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat spram "rtl/memories/spram.v" "rtl/memories/tb_spram.v"
// Outputs: sim\spram.*   build\spram_gates.*   build\spram_sky130.*
// ===========================================================================
`timescale 1ns/1ps

module spram #(
  parameter DW = 8,          // data width
  parameter AW = 4           // address width -> depth = 2**AW
) (
  input  wire          clk,
  input  wire          we,    // write enable
  input  wire [AW-1:0] addr,  // shared read/write address
  input  wire [DW-1:0] din,   // write data
  output reg  [DW-1:0] dout   // registered read data
);

  reg [DW-1:0] mem [0:(1<<AW)-1];

  always @(posedge clk) begin
    if (we) mem[addr] <= din;  // synchronous write
    dout <= mem[addr];         // registered read  (READ-FIRST as written)
  end

endmodule
