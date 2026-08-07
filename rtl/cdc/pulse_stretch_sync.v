// ===========================================================================
// pulse_stretch_sync.v  --  PULSE-STRETCH synchronizer (fast -> slow).
// ---------------------------------------------------------------------------
// Problem: a 1-cycle pulse in a FAST source domain can fall entirely between
// two edges of a SLOWER destination clock and be lost.
//
// Fix shown here: STRETCH the pulse in the source domain to STRETCH cycles so
// it is guaranteed wide enough for the slow clock to sample at least once, then
// pass that wide level through a 2-FF synchronizer and edge-detect it in the
// destination to recover a single clean 1-cycle pulse.
//
// Contrast with pulse_sync (toggle method): stretching only works when source
// pulses are spaced far enough apart that their stretched levels do NOT merge.
// The toggle method has no minimum pulse width but still needs event spacing.
// Pick stretch for occasional fast->slow strobes; pick toggle for general use.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat pulse_stretch_sync "rtl/cdc/pulse_stretch_sync.v" "rtl/cdc/tb_pulse_stretch_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module pulse_stretch_sync #(
  parameter STRETCH = 3          // source cycles to hold the pulse high
) (
  input  wire src_clk,
  input  wire src_rst_n,
  input  wire src_pulse,         // 1-cycle pulse in the fast domain
  input  wire dst_clk,
  input  wire dst_rst_n,
  output wire dst_pulse          // recovered 1-cycle pulse in the slow domain
);

  // ---- source: widen the pulse to STRETCH cycles ----
  reg [STRETCH-1:0] shift;
  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) shift <= {STRETCH{1'b0}};
    else            shift <= {shift[STRETCH-2:0], src_pulse};

  wire wide = src_pulse | (|shift);

  // ---- destination: 2-FF sync + rising-edge detect ----
  reg [2:0] sync;
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) sync <= 3'b0;
    else            sync <= {sync[1:0], wide};

  assign dst_pulse = sync[1] & ~sync[2];   // one pulse per stretched level

endmodule
