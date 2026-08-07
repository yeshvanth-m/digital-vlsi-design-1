// ===========================================================================
// pulse_sync.v  --  pass a SINGLE-CYCLE pulse from one clock domain to another.
// ---------------------------------------------------------------------------
// You cannot 2-FF-sync a one-cycle pulse directly: if the destination clock is
// slower it may miss the pulse entirely, and if faster it may see it twice.
// The classic fix is the TOGGLE synchronizer:
//   1. In the source domain, FLIP a toggle flop once per input pulse. The
//      toggle is a stable level, so it is safe to 2-FF-sync.
//   2. In the destination domain, sync the toggle and EDGE-DETECT it. Each edge
//      (either direction) regenerates exactly one destination-domain pulse.
//
// LIMITATION (teach this!): input pulses must be spaced far enough apart that
// the destination can register each toggle edge -- roughly >= 2 destination
// clocks between pulses. Back-to-back source pulses can be lost.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat pulse_sync "rtl/cdc/pulse_sync.v" "rtl/cdc/tb_pulse_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module pulse_sync (
  input  wire src_clk,
  input  wire src_rst_n,
  input  wire src_pulse,        // one-cycle pulse in the source domain
  input  wire dst_clk,
  input  wire dst_rst_n,
  output wire dst_pulse         // one-cycle pulse in the destination domain
);

  // --- source domain: convert each pulse into a toggle (a stable level) ---
  reg toggle;
  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n)      toggle <= 1'b0;
    else if (src_pulse)  toggle <= ~toggle;

  // --- destination domain: 2-FF sync + one extra flop for edge detect ---
  reg [2:0] sync;
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) sync <= 3'b000;
    else            sync <= {sync[1:0], toggle};

  // An edge on the synced toggle == one source pulse.
  assign dst_pulse = sync[2] ^ sync[1];

endmodule
