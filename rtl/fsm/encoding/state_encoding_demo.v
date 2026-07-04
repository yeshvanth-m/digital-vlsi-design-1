// ===========================================================================
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat state_encoding_demo "rtl/fsm/encoding/state_encoding_demo.v rtl/fsm/moore/moore_101_fsm.v" "rtl/fsm/encoding/tb_state_encoding_demo.v" ENCODING=ONEHOT
// Change the encoding via the last arg: ENCODING=BINARY | GRAY | ONEHOT | ONECOLD
// Outputs: sim\state_encoding_demo.*   build\state_encoding_demo_gates.*   build\state_encoding_demo_sky130.*
// ===========================================================================
// state_encoding_demo.v  --  ONE FSM, FOUR selectable state encodings
// ---------------------------------------------------------------------------
// The machine is the overlapping Moore "101" detector (states A,B,C,D).
// The *behaviour* is identical for every encoding -- only the bit pattern of
// the state register (and therefore the synthesized gates / risk profile)
// changes. Select the encoding with the ENCODING parameter:
//
//   "BINARY"  : 00 01 10 11      -> 2 flip-flops, dense, fewest FFs
//   "GRAY"    : 00 01 11 10      -> 2 flip-flops, adjacent codes differ by 1 bit
//   "ONEHOT"  : 0001 0010 0100 1000 -> 4 flip-flops, 1 hot bit, simple decode
//   "ONECOLD" : 1110 1101 1011 0111 -> 4 flip-flops, 1 cold bit (inverse one-hot)
//
// Teaching point: the `default` branch makes this a SAFE FSM -- any illegal /
// unreachable code (12 of the 16 one-hot patterns are illegal) recovers to A
// instead of locking up.
//
// Run (compares all four encodings against the golden moore_101_fsm):
//   iverilog -o sim/state_encoding_demo.vvp \
//       rtl/fsm/encoding/state_encoding_demo.v \
//       rtl/fsm/moore/moore_101_fsm.v \
//       rtl/fsm/encoding/tb_state_encoding_demo.v
//   vvp sim/state_encoding_demo.vvp
// ===========================================================================
`timescale 1ns/1ps

module state_encoding_demo #(
  parameter ENCODING = "ONEHOT"     // BINARY | GRAY | ONEHOT | ONECOLD
)(
  input  wire clk,
  input  wire rst_n,                // active-low async reset
  input  wire w,                    // serial input bit
  output wire z                     // 1 = "101" detected (Moore)
);

  // One-hot / one-cold need one flip-flop per state (4); the dense codes need
  // only ceil(log2(4)) = 2 flip-flops.
  localparam SW = (ENCODING == "ONEHOT" || ENCODING == "ONECOLD") ? 4 : 2;

  // Per-encoding codes for the four states (lower SW bits are the ones used).
  localparam [3:0] A = (ENCODING == "ONEHOT")  ? 4'b0001 :
                       (ENCODING == "ONECOLD") ? 4'b1110 :
                       (ENCODING == "GRAY")    ? 4'b0000 : 4'b0000;
  localparam [3:0] B = (ENCODING == "ONEHOT")  ? 4'b0010 :
                       (ENCODING == "ONECOLD") ? 4'b1101 :
                       (ENCODING == "GRAY")    ? 4'b0001 : 4'b0001;
  localparam [3:0] C = (ENCODING == "ONEHOT")  ? 4'b0100 :
                       (ENCODING == "ONECOLD") ? 4'b1011 :
                       (ENCODING == "GRAY")    ? 4'b0011 : 4'b0010;
  localparam [3:0] D = (ENCODING == "ONEHOT")  ? 4'b1000 :
                       (ENCODING == "ONECOLD") ? 4'b0111 :
                       (ENCODING == "GRAY")    ? 4'b0010 : 4'b0011;

  reg [SW-1:0] state, next;

  // Next-state logic -- identical FSM for every encoding.
  always @(*) begin
    case (state)
      A[SW-1:0]: next = w ? B[SW-1:0] : A[SW-1:0];  // A: saw nothing
      B[SW-1:0]: next = w ? B[SW-1:0] : C[SW-1:0];  // B: saw 1
      C[SW-1:0]: next = w ? D[SW-1:0] : A[SW-1:0];  // C: saw 10
      D[SW-1:0]: next = w ? B[SW-1:0] : C[SW-1:0];  // D: saw 101 (overlap)
      default:   next = A[SW-1:0];                  // SAFE: recover from illegal codes
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= A[SW-1:0];   // note: one-cold/one-hot reset code is NOT all-zero
    else        state <= next;
  end

  assign z = (state == D[SW-1:0]);    // Moore: output is a function of state only

endmodule
