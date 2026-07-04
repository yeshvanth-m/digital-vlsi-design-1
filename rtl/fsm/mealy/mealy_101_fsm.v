// ===========================================================================
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat mealy_101_fsm "rtl/fsm/mealy/mealy_101_fsm.v" "rtl/fsm/mealy/tb_mealy_101_fsm.v"
// Outputs: sim\mealy_101_fsm.*   build\mealy_101_fsm_gates.*   build\mealy_101_fsm_sky130.*
// ===========================================================================
`timescale 1ns/1ps
// Mealy "101" overlapping sequence detector (z = 1 SAME cycle as final '1').
// States: S0=- , S1="1", S2="10".
module mealy_101_fsm (
  input  wire clk, rst_n, w,
  output wire z
);
  localparam S0=2'd0, S1=2'd1, S2=2'd2;
  reg [1:0] state, next;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) state <= S0;
    else        state <= next;

  always @(*) case (state)
    S0:      next = w ? S1 : S0;
    S1:      next = w ? S1 : S2;
    S2:      next = w ? S1 : S0;   // overlap
    default: next = S0;
  endcase
  // Mealy: output = state AND input
  assign z = (state == S2) & w;    
endmodule
