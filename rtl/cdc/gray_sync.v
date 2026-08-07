// ===========================================================================
// gray_sync.v  --  cross a MULTI-BIT monotonic COUNTER between clock domains.
// ---------------------------------------------------------------------------
// You cannot 2-FF-sync a binary counter: several bits can change on one count
// (e.g. 0111 -> 1000), and they will not all arrive in the destination on the
// same clock -> the destination could sample garbage like 1111 or 0000.
// GRAY code fixes this: successive values differ in exactly ONE bit, so a value
// sampled mid-flight is always either the old or the new count -- never wrong.
// This is exactly how the async FIFO crosses its read/write pointers.
//
// Flow:  bin (src) --(bin->gray)--> gray --2FF--> gray_d --(gray->bin)--> dst_bin
// Only valid for a counter that changes by <= 1 per source clock.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat gray_sync "rtl/cdc/gray_sync.v" "rtl/cdc/tb_gray_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module gray_sync #(
  parameter W = 4
) (
  input  wire         src_clk,
  input  wire         src_rst_n,
  input  wire         incr,          // count enable in the source domain
  output wire [W-1:0] src_bin,       // the true source count (for reference)
  input  wire         dst_clk,
  input  wire         dst_rst_n,
  output reg  [W-1:0] dst_bin        // source count observed in dst domain
);

  // --- source counter, kept in both binary and Gray form ---
  reg [W-1:0] bin, gray;
  wire [W-1:0] bin_nxt  = bin + (incr ? 1'b1 : 1'b0);
  wire [W-1:0] gray_nxt = bin_nxt ^ (bin_nxt >> 1);

  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) begin bin <= 0; gray <= 0; end
    else            begin bin <= bin_nxt; gray <= gray_nxt; end

  assign src_bin = bin;

  // --- 2-FF sync of the Gray value into the destination domain ---
  reg [W-1:0] g1, g2;
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) begin g1 <= 0; g2 <= 0; end
    else            begin g1 <= gray; g2 <= g1; end

  // --- Gray -> binary in the destination, then register it ---
  integer k;
  reg [W-1:0] b;
  always @* begin
    b[W-1] = g2[W-1];
    for (k = W-2; k >= 0; k = k - 1)
      b[k] = b[k+1] ^ g2[k];
  end

  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) dst_bin <= 0;
    else            dst_bin <= b;

endmodule
