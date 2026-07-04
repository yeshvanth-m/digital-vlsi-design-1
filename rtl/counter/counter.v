// ===========================================================================
// counter.v  --  4-bit free-running up-counter used to demonstrate that
//                `reg` DOES NOT guarantee a storage element.
// ---------------------------------------------------------------------------
// BOTH `count` and `tc` are declared `reg`, yet synthesis infers:
//   * count : 4 flip-flops   (clocked  -> storage IS inferred)
//   * tc    : 0 flip-flops   (combinational compare -> NO storage)
// The keyword is identical; only the *assignment context* decides.
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat counter "rtl/counter/counter.v" "rtl/counter/tb_counter.v"
// Outputs: sim\counter.*   build\counter_gates.*   build\counter_sky130.*
//   count -> flip-flops ($_DFF_ / dfrtp_1);  tc -> pure gates (no FF).
// ===========================================================================
`timescale 1ns/1ps

module counter (
  input  wire       clk,
  input  wire       rst_n,   // active-low async reset
  output reg  [3:0] count,   // reg + posedge clk  -> flip-flops (storage)
  output reg        tc       // reg + always @(*)  -> pure gates (NO storage)
);

  // Sequential: free-running -> increments every clock -> real flip-flops.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  count <= 4'd0;
    else         count <= count + 4'd1;
  end

  // Combinational: recomputed every time count changes -> no storage.
  // (Declared `reg` only because it is assigned procedurally.)
  always @(*) begin
    tc = (count == 4'd15);
  end

endmodule
