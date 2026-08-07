// ===========================================================================
// edge_sync.v  --  EDGE synchronizer (level sync + edge detector).
// ---------------------------------------------------------------------------
// Crosses a LEVEL into another clock domain with an ordinary N-FF synchronizer,
// then detects its transition in the destination to produce a clean 1-cycle
// strobe. This is the "edge synchronizer": use it when the source presents a
// LEVEL (a flag that stays set) and the destination clock is fast enough to see
// it -- simpler than the toggle/pulse synchronizer, but it will MISS a level
// that is narrower than the destination sampling window (that case needs
// pulse_sync's toggle method or pulse_stretch_sync).
//
// EDGE selects the "Edge Detector Type":
//   0 = rising  (0 -> 1)
//   1 = falling (1 -> 0)
//   2 = both    (any change)
//
//   dst_level : the synchronized level (STAGES-deep).
//   dst_edge  : 1-cycle strobe, aligned with dst_level changing.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat edge_sync "rtl/cdc/edge_sync.v" "rtl/cdc/tb_edge_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module edge_sync #(
  parameter STAGES = 2,
  parameter EDGE   = 0            // 0=rising, 1=falling, 2=both
) (
  input  wire dst_clk,
  input  wire dst_rst_n,
  input  wire async_in,          // level from another clock domain
  output wire dst_level,         // synchronized level
  output wire dst_edge           // 1-cycle strobe on the selected edge
);

  reg [STAGES-1:0] ff;           // the synchronizer chain
  reg              prev;         // synchronized value one clock ago

  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) begin
      ff   <= {STAGES{1'b0}};
      prev <= 1'b0;
    end else begin
      ff   <= {ff[STAGES-2:0], async_in};
      prev <= ff[STAGES-1];
    end

  wire synced = ff[STAGES-1];
  wire rise   =  synced & ~prev;
  wire fall   = ~synced &  prev;

  assign dst_level = synced;
  assign dst_edge  = (EDGE == 0) ? rise :
                     (EDGE == 1) ? fall :
                                   (rise | fall);

endmodule
