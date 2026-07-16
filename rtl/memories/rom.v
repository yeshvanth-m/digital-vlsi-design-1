// ===========================================================================
// rom.v  --  synchronous ROM (parameterized), initialized from a hex file.
// ---------------------------------------------------------------------------
// Contents are fixed at build time via $readmemh. Used for constants, LUTs and
// microcode. On an FPGA the init comes from the bitstream; on an ASIC the ROM
// is mask-programmed (or loaded from flash at boot). Registered read output.
// The INIT_FILE path is relative to the simulation run directory
// (C:\digital-design-tools per the BUILD line below).
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat rom "rtl/memories/rom.v" "rtl/memories/tb_rom.v"
// Outputs: sim\rom.*   build\rom_gates.*   build\rom_sky130.*
// ===========================================================================
`timescale 1ns/1ps

module rom #(
  parameter DW = 8,          // data width
  parameter AW = 4,          // address width -> depth = 2**AW
  parameter INIT_FILE = "rtl/memories/rom_init.hex"
) (
  input  wire          clk,
  input  wire [AW-1:0] addr,
  output reg  [DW-1:0] dout   // registered read data
);

  reg [DW-1:0] mem [0:(1<<AW)-1];

  initial $readmemh(INIT_FILE, mem);

  always @(posedge clk)
    dout <= mem[addr];

endmodule
