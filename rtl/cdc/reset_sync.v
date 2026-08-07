// ===========================================================================
// reset_sync.v  --  reset synchronizer (async assert, sync de-assert).
// ---------------------------------------------------------------------------
// THE most important CDC primitive. A reset coming from a button or another
// domain is asynchronous to `clk`. If you release it near a clock edge the
// flops can go metastable. The fix: let the reset ASSERT asynchronously (fast,
// immediate), but DE-ASSERT synchronously by clocking 1s through a short shift
// register so every flop leaves reset on the same, clean clock edge.
//
//   async_rst_n = 0  -> sync_rst_n = 0 immediately (async assert)
//   async_rst_n = 1  -> sync_rst_n = 1 after STAGES clk edges (sync release)
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat reset_sync "rtl/cdc/reset_sync.v" "rtl/cdc/tb_reset_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module reset_sync #(
  parameter STAGES = 2          // synchronizer depth (2 is typical)
) (
  input  wire clk,
  input  wire async_rst_n,      // active-low, asynchronous
  output wire sync_rst_n        // active-low, de-asserts synchronously to clk
);

  reg [STAGES-1:0] sync;

  always @(posedge clk or negedge async_rst_n)
    if (!async_rst_n)
      sync <= {STAGES{1'b0}};              // async assert: force all 0
    else
      sync <= {sync[STAGES-2:0], 1'b1};    // shift 1s in on release

  assign sync_rst_n = sync[STAGES-1];

endmodule
