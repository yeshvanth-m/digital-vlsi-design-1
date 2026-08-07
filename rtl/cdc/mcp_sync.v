// ===========================================================================
// mcp_sync.v  --  MCP / 2-phase data synchronizer (MUX-recirculation).
// ---------------------------------------------------------------------------
// Moves a MULTI-BIT word across clock domains without a FIFO. Also called the
// "MUX recirculation" or "Multi-Cycle-Path (MCP) formulation".
//
// Idea: the data bus is NEVER synchronized directly. Only ONE control bit (a
// toggle) crosses through a synchronizer. While that toggle propagates, the
// data bus sits still in data_hold, so the destination can capture it after the
// control bit safely arrives -- the bus is treated as a multi-cycle path.
//
// This version is a 2-PHASE handshake (contrast handshake_sync.v, which is
// 4-phase level req/ack):
//   src_load & !src_busy : latch src_data, flip req toggle, raise src_busy.
//   dst side sees req flip -> capture data_hold, pulse dst_valid, flip ack.
//   src sees ack flip      -> drop src_busy (safe to send the next word).
//
// Throughput is one word per full round-trip (slower than a FIFO) but it costs
// only a handful of flops and no memory. Great when updates are infrequent
// (config/status registers). The source MUST honor src_busy.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat mcp_sync "rtl/cdc/mcp_sync.v" "rtl/cdc/tb_mcp_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module mcp_sync #(
  parameter DW = 8
) (
  // source domain
  input  wire          src_clk,
  input  wire          src_rst_n,
  input  wire          src_load,      // request to send src_data (1-cycle)
  input  wire [DW-1:0] src_data,
  output reg           src_busy,       // high while a word is in flight
  // destination domain
  input  wire          dst_clk,
  input  wire          dst_rst_n,
  output reg           dst_valid,      // 1-cycle strobe when dst_data updates
  output reg  [DW-1:0] dst_data
);

  reg [DW-1:0] data_hold;             // multi-cycle path (held stable in flight)
  reg          req_tog;               // src -> dst
  reg          ack_tog;               // dst -> src

  // ---- ack toggle synchronized back into the source domain ----
  reg [2:0] ack_s;
  wire ack_edge = ack_s[2] ^ ack_s[1];
  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) ack_s <= 3'b0;
    else            ack_s <= {ack_s[1:0], ack_tog};

  // ---- source control ----
  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) begin
      req_tog   <= 1'b0;
      src_busy  <= 1'b0;
      data_hold <= {DW{1'b0}};
    end else if (src_load && !src_busy) begin
      data_hold <= src_data;          // park the bus, then announce it
      req_tog   <= ~req_tog;
      src_busy  <= 1'b1;
    end else if (ack_edge) begin
      src_busy  <= 1'b0;              // destination captured it
    end

  // ---- req toggle synchronized into the destination domain ----
  reg [2:0] req_s;
  wire req_edge = req_s[2] ^ req_s[1];
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) req_s <= 3'b0;
    else            req_s <= {req_s[1:0], req_tog};

  // ---- destination capture ----
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) begin
      dst_valid <= 1'b0;
      dst_data  <= {DW{1'b0}};
      ack_tog   <= 1'b0;
    end else begin
      dst_valid <= 1'b0;
      if (req_edge) begin
        dst_data  <= data_hold;       // bus is stable: safe multi-cycle capture
        dst_valid <= 1'b1;
        ack_tog   <= ~ack_tog;
      end
    end

endmodule
