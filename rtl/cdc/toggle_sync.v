// ===========================================================================
// toggle_sync.v  --  TOGGLE synchronizer (reusable primitive).
// ---------------------------------------------------------------------------
// The building block behind pulse / event crossing. Instead of trying to pass
// a short pulse (which the receiving clock can MISS), the source encodes each
// event as a TOGGLE of a level: every event flips src_toggle. A level is safe
// to run through a 2-FF synchronizer. On the destination side we compare the
// last two synchronized samples: a difference means "the level flipped since
// last clock" => exactly one event happened.
//
//   dst_level  : the synchronized copy of the toggle level.
//   dst_change : 1-cycle strobe in the destination domain, one per source flip.
//
// RULE: the source must not toggle faster than the destination can sample
// (>= ~2 dst clocks between flips) or events coalesce. For back-to-back events
// use a FIFO or a handshake instead. pulse_sync = this primitive wired so each
// source pulse produces one flip; mcp_sync uses two of these (req + ack).
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat toggle_sync "rtl/cdc/toggle_sync.v" "rtl/cdc/tb_toggle_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module toggle_sync #(
  parameter STAGES = 2
) (
  input  wire dst_clk,
  input  wire dst_rst_n,
  input  wire src_toggle,        // toggle-encoded signal from another domain
  output wire dst_level,         // synchronized toggle level
  output wire dst_change         // 1-cycle pulse each time the toggle flips
);

  reg [STAGES:0] sync;           // one extra flop to hold the previous sample

  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n)
      sync <= {(STAGES+1){1'b0}};
    else
      sync <= {sync[STAGES-1:0], src_toggle};

  assign dst_level  = sync[STAGES];
  assign dst_change = sync[STAGES] ^ sync[STAGES-1];

endmodule
