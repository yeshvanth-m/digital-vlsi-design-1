// ===========================================================================
// regfile.v  --  2-read / 1-write register file (parameterized).
// ---------------------------------------------------------------------------
// Synchronous WRITE, asynchronous (combinational) READ. This async-read style
// infers FLOPS / distributed LUT-RAM -- NOT block RAM -- which is exactly what
// a CPU register file needs for single-cycle reads.
// NOTE: the array is intentionally NOT reset (resetting a whole memory blocks
//       RAM inference; reset outputs/pointers instead, not the storage).
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat regfile "rtl/memories/regfile.v" "rtl/memories/tb_regfile.v"
// Outputs: sim\regfile.*   build\regfile_gates.*   build\regfile_sky130.*
// ===========================================================================
`timescale 1ns/1ps

module regfile #(
  parameter DW = 8,          // data width
  parameter AW = 4           // address width -> depth = 2**AW
) (
  input  wire          clk,
  input  wire          we,    // write enable
  input  wire [AW-1:0] wa,    // write address
  input  wire [AW-1:0] ra0,   // read address, port 0
  input  wire [AW-1:0] ra1,   // read address, port 1
  input  wire [DW-1:0] wd,    // write data
  output wire [DW-1:0] rd0,   // read data, port 0 (async)
  output wire [DW-1:0] rd1    // read data, port 1 (async)
);

  reg [DW-1:0] mem [0:(1<<AW)-1];

  // Synchronous write.
  always @(posedge clk)
    if (we) mem[wa] <= wd;

  // Asynchronous (combinational) reads.
  assign rd0 = mem[ra0];
  assign rd1 = mem[ra1];

endmodule
