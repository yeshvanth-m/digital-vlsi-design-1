// ===========================================================================
// handshake_sync.v  --  MULTI-BIT data transfer across clocks via a 4-phase
//                       req/ack handshake.
// ---------------------------------------------------------------------------
// When you must move a whole BUS (not a counter) between unrelated clocks and
// you cannot use a FIFO, use a request/acknowledge handshake:
//   1. Source latches the data and raises REQ.
//   2. REQ is 2-FF-synced into the destination; on seeing it, the destination
//      CAPTURES the (now stable) data and raises ACK.
//   3. ACK is 2-FF-synced back; the source drops REQ.
//   4. Destination drops ACK; source is ready for the next word.
// Only the 1-bit REQ and ACK ever cross domains -- the data bus is sampled by
// the destination only while it is guaranteed stable, so no Gray code needed.
// Throughput is low (a few cycles per word); that is the price of simplicity.
//
// Self-contained: the 2-FF synchronizers are inlined (same pattern as
// two_ff_sync.v) so this module compiles on its own.
// ---------------------------------------------------------------------------
//   scripts\run_flow.bat handshake_sync "rtl/cdc/handshake_sync.v" "rtl/cdc/tb_handshake_sync.v"
// ===========================================================================
`timescale 1ns/1ps

module handshake_sync #(
  parameter DW = 8
) (
  // ---- source domain ----
  input  wire          src_clk,
  input  wire          src_rst_n,
  input  wire          src_valid,   // pulse/level: request to send src_data
  input  wire [DW-1:0] src_data,
  output reg           src_ready,   // high when a new word can be accepted
  // ---- destination domain ----
  input  wire          dst_clk,
  input  wire          dst_rst_n,
  output reg           dst_valid,   // one-cycle strobe: dst_data is new
  output reg  [DW-1:0] dst_data
);

  // Data captured in the source domain, held stable across the handshake.
  reg [DW-1:0] data_hold;
  reg          req;                 // source -> destination
  reg          ack;                 // destination -> source

  // 2-FF synchronizers for the two crossing signals.
  reg [1:0] req_sync;               // req into destination domain
  reg [1:0] ack_sync;               // ack into source domain
  wire      req_d = req_sync[1];
  wire      ack_s = ack_sync[1];

  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) req_sync <= 2'b00;
    else            req_sync <= {req_sync[0], req};

  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) ack_sync <= 2'b00;
    else            ack_sync <= {ack_sync[0], ack};

  // ---- source FSM (4-phase) ----
  localparam S_IDLE = 2'd0, S_REQ = 2'd1, S_DROP = 2'd2;
  reg [1:0] sstate;
  always @(posedge src_clk or negedge src_rst_n)
    if (!src_rst_n) begin
      sstate <= S_IDLE; req <= 1'b0; src_ready <= 1'b1; data_hold <= {DW{1'b0}};
    end else case (sstate)
      S_IDLE : if (src_valid && src_ready) begin
                 data_hold <= src_data;  // latch while stable
                 req       <= 1'b1;
                 src_ready <= 1'b0;
                 sstate    <= S_REQ;
               end
      S_REQ  : if (ack_s) begin          // destination captured it
                 req    <= 1'b0;
                 sstate <= S_DROP;
               end
      S_DROP : if (!ack_s) begin          // handshake complete
                 src_ready <= 1'b1;
                 sstate    <= S_IDLE;
               end
      default: sstate <= S_IDLE;
    endcase

  // ---- destination FSM ----
  localparam D_IDLE = 1'b0, D_ACK = 1'b1;
  reg dstate;
  always @(posedge dst_clk or negedge dst_rst_n)
    if (!dst_rst_n) begin
      dstate <= D_IDLE; ack <= 1'b0; dst_valid <= 1'b0; dst_data <= {DW{1'b0}};
    end else begin
      dst_valid <= 1'b0;                  // default: strobe is one cycle
      case (dstate)
        D_IDLE : if (req_d) begin
                   dst_data  <= data_hold; // data is stable here
                   dst_valid <= 1'b1;
                   ack       <= 1'b1;
                   dstate    <= D_ACK;
                 end
        D_ACK  : if (!req_d) begin
                   ack    <= 1'b0;
                   dstate <= D_IDLE;
                 end
      endcase
    end

endmodule
