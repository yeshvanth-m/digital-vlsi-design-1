// ===========================================================================
// nff_sync.v  --  N-FLOP level synchronizer (2-FF, 3-FF, 4-FF ...).
// ---------------------------------------------------------------------------
// A 2-FF synchronizer is the default, but the metastability of the FIRST flop
// is only *probably* resolved in one clock. At very high destination clock
// frequencies (short settling window) or for safety-critical logic you add
// MORE stages: each extra flop gives the metastable event another full clock to
// decay, raising the Mean-Time-Between-Failures (MTBF) exponentially -- at the
// cost of one extra cycle of latency per stage.
//   STAGES = 2 : textbook default
//   STAGES = 3 : common at high clock rates / for reset & critical controls
//   STAGES = 4 : very conservative
// Same single-bit rule as two_ff_sync: NEVER feed a multi-bit bus through this.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat nff_sync "rtl/cdc/nff_sync.v" "rtl/cdc/tb_nff_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module nff_sync #(
  parameter STAGES  = 3,        // number of destination flops (>= 2)
  parameter RST_VAL = 1'b0      // value the chain holds while in reset
) (
  input  wire dst_clk,
  input  wire dst_rst_n,
  input  wire din,              // asynchronous single-bit level
  output wire dout              // synchronized level, STAGES clocks later
);

  reg [STAGES-1:0] sync;

  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n)
      sync <= {STAGES{RST_VAL}};
    else
      sync <= {sync[STAGES-2:0], din};

  assign dout = sync[STAGES-1];

endmodule
