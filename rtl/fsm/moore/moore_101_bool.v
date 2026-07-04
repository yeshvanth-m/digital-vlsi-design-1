// ===========================================================================
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat moore_101_bool "rtl/fsm/moore/moore_101_bool.v" "rtl/fsm/moore/tb_moore_101_bool.v"
// Outputs: sim\moore_101_bool.*   build\moore_101_bool_gates.*   build\moore_101_bool_sky130.*
// ===========================================================================
// Moore "101" sequence detector  -- boolean-equation coding style
// ---------------------------------------------------------------------------
// Same machine as moore_101_fsm.v, but the next-state and output logic are
// written directly as boolean equations on the state bits {q1,q0} instead of
// a case statement. State encoding S0=00, S1=01, S2=10, S3=11.
//
// Derived equations (see truth table in moore_101_fsm.v):
//   n0 = w
//   n1 = (q0 & ~w) | (q1 & ~q0 & w)
//   z  = q1 & q0                        (Moore: state only)
//
// Run:
//   iverilog -o sim/moore_101_bool.vvp examples/moore_101_bool.v examples/tb_moore_101_bool.v
//   vvp sim/moore_101_bool.vvp
//   gtkwave sim/moore_101_bool.vcd
// ===========================================================================
`timescale 1ns/1ps

module moore_101_bool (
  input  wire clk,
  input  wire rst_n,    // active-low async reset
  input  wire w,        // serial input bit
  output wire z          // 1 = "101" detected
);

  reg  q1, q0;          // state bits {q1,q0}

  wire n1 = (q0 & ~w) | (q1 & ~q0 & w);
  wire n0 = w;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) {q1, q0} <= 2'b00;
    else        {q1, q0} <= {n1, n0};
  end

  assign z = q1 & q0;

endmodule
