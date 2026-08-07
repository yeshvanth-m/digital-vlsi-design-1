// ===========================================================================
// two_ff_sync.v  --  two-flop (level) synchronizer for a SINGLE-BIT signal.
// ---------------------------------------------------------------------------
// The workhorse of CDC. A single-bit level generated in one clock domain is
// sampled by two (or more) back-to-back flops in the destination domain. If the
// first flop goes metastable, it has a full destination clock period to settle
// before the second flop samples it, so downstream logic sees a clean 0 or 1.
//
// RULES this primitive relies on:
//   * ONE bit only. Never sync a multi-bit bus this way (bits would arrive on
//     different cycles). Use Gray coding (gray_sync) or a handshake instead.
//   * The source signal must stay stable long enough for the destination to
//     sample it (at least ~2 destination clocks for a pulse -> see pulse_sync).
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat two_ff_sync "rtl/cdc/two_ff_sync.v" "rtl/cdc/tb_two_ff_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module two_ff_sync #(
  parameter STAGES = 2          // number of destination flops (>= 2)
) (
  input  wire dst_clk,
  input  wire dst_rst_n,
  input  wire din,              // asynchronous level from the source domain
  output wire dout              // synchronized level in the destination domain
);

  reg [STAGES-1:0] sync;

  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n)
      sync <= {STAGES{1'b0}};
    else
      sync <= {sync[STAGES-2:0], din};

  assign dout = sync[STAGES-1];

endmodule
