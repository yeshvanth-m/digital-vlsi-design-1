// ===========================================================================
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat mealy_101_bool "rtl/fsm/mealy/mealy_101_bool.v" "rtl/fsm/mealy/tb_mealy_101_bool.v"
// Outputs: sim\mealy_101_bool.*   build\mealy_101_bool_gates.*   build\mealy_101_bool_sky130.*
// ===========================================================================
// Mealy "101" sequence detector  -- boolean-equation coding style
// ---------------------------------------------------------------------------
// Same machine as mealy_101_fsm.v, written as boolean equations on the state
// bits {q1,q0}. State encoding S0=00, S1=01, S2=10 (11 unused).
//
// Derived equations (literal sum-of-minterms from the truth table):
//   n0 = w
//   n1 = ~q1 & q0 & ~w     (full expansion; not minimized via the unused 11)
//   z  = q1 & w            (Mealy: state AND input)
//
// Run:
//   iverilog -o sim/mealy_101_bool.vvp examples/mealy_101_bool.v examples/tb_mealy_101_bool.v
//   vvp sim/mealy_101_bool.vvp
//   gtkwave sim/mealy_101_bool.vcd
// ===========================================================================
`timescale 1ns/1ps

module mealy_101_bool (
  input  wire clk,
  input  wire rst_n,    // active-low async reset
  input  wire w,        // serial input bit
  output wire z         // 1 = "101" detected
);

  reg  q1, q0;          // state bits {q1,q0}

  wire n1 = ~q1 & q0 & ~w;
  wire n0 = w;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) {q1, q0} <= 2'b00;
    else        {q1, q0} <= {n1, n0};
  end

  assign z = q1 & w;

endmodule

