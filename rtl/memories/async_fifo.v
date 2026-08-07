// ===========================================================================
// async_fifo.v  --  asynchronous (dual-clock) FIFO, parameterized.
// ---------------------------------------------------------------------------
// A FIFO whose write and read sides run on INDEPENDENT clocks (wr_clk, rd_clk).
// Crossing the clock domains safely is the whole job here, and the classic
// Cummings solution is used (see Sunburst Design, "Simulation and Synthesis
// Techniques for Asynchronous FIFO Design"):
//   * Pointers carry ONE EXTRA MSB above the address bits so FULL vs EMPTY can
//     be told apart when the low bits are equal (same trick as sync_fifo.v).
//   * Pointers are converted to GRAY code before crossing clock domains. Gray
//     code changes only one bit per increment, so a value sampled mid-flight by
//     the other domain is always either the old or the new count -- never a
//     bogus in-between value.
//   * Each Gray pointer is passed through a 2-FF SYNCHRONIZER into the opposite
//     domain before the flag comparison, to resolve metastability.
//   * FULL and EMPTY are REGISTERED (not combinational). This both cleans the
//     timing AND avoids a combinational loop: the next binary pointer depends
//     on the flag, and the flag depends on the pointer -- so the flag must come
//     from a flop to break the cycle.
//   empty : rd_gray_next == synchronized wr_gray                (read domain)
//   full  : wr_gray_next == {~sync rd_gray[MSBs], sync rd_gray} (write domain)
// ---------------------------------------------------------------------------
// BUILD (simulate + generic synth + Sky130 synth) -- from C:\digital-design-tools:
//   scripts\run_flow.bat async_fifo "rtl/memories/async_fifo.v" "rtl/memories/tb_async_fifo.v"
// Outputs: sim\async_fifo.*   build\async_fifo_gates.*   build\async_fifo_sky130.*
// ===========================================================================
`timescale 1ns/1ps

module async_fifo #(
  parameter DW = 8,          // data width
  parameter AW = 3           // address width -> depth = 2**AW
) (
  // ---- write domain ----
  input  wire          wr_clk,
  input  wire          wr_rst_n,   // active-low async-assert reset, wr domain
  input  wire          wr_en,
  input  wire [DW-1:0] din,
  output reg           full,
  // ---- read domain ----
  input  wire          rd_clk,
  input  wire          rd_rst_n,   // active-low async-assert reset, rd domain
  input  wire          rd_en,
  output reg  [DW-1:0] dout,
  output reg           empty
);

  // Storage: simple dual-port RAM, written in wr_clk, read in rd_clk.
  reg [DW-1:0] mem [0:(1<<AW)-1];

  // Binary and Gray pointers (AW+1 bits: extra MSB for full/empty).
  reg  [AW:0] wbin, wgray;   // write pointer (write domain)
  reg  [AW:0] rbin, rgray;   // read  pointer (read  domain)

  // Cross-domain synchronizers (2-FF each).
  reg  [AW:0] wgray_rd1, wgray_rd2;  // write-gray sampled into read domain
  reg  [AW:0] rgray_wr1, rgray_wr2;  // read-gray  sampled into write domain

  // Binary -> Gray helper.
  function [AW:0] bin2gray(input [AW:0] b);
    bin2gray = b ^ (b >> 1);
  endfunction

  // -------------------------------------------------------------------------
  // WRITE DOMAIN
  // -------------------------------------------------------------------------
  // Next-state uses the REGISTERED full, so there is no combinational loop.
  wire [AW:0] wbin_next  = wbin + (wr_en && !full);
  wire [AW:0] wgray_next = bin2gray(wbin_next);
  // FULL when the next write Gray matches the synced read Gray with the top
  // TWO bits inverted.
  wire        full_next  = (wgray_next ==
                            {~rgray_wr2[AW:AW-1], rgray_wr2[AW-2:0]});

  always @(posedge wr_clk or negedge wr_rst_n)
    if (!wr_rst_n) begin
      wbin  <= 0;
      wgray <= 0;
      full  <= 1'b0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
      full  <= full_next;
    end

  // RAM write port.
  always @(posedge wr_clk)
    if (wr_en && !full)
      mem[wbin[AW-1:0]] <= din;

  // Synchronize the READ Gray pointer into the WRITE domain.
  always @(posedge wr_clk or negedge wr_rst_n)
    if (!wr_rst_n) begin
      rgray_wr1 <= 0;
      rgray_wr2 <= 0;
    end else begin
      rgray_wr1 <= rgray;
      rgray_wr2 <= rgray_wr1;
    end

  // -------------------------------------------------------------------------
  // READ DOMAIN
  // -------------------------------------------------------------------------
  // Next-state uses the REGISTERED empty, so there is no combinational loop.
  wire [AW:0] rbin_next  = rbin + (rd_en && !empty);
  wire [AW:0] rgray_next = bin2gray(rbin_next);
  // EMPTY when the next read Gray matches the synchronized write Gray.
  wire        empty_next = (rgray_next == wgray_rd2);

  always @(posedge rd_clk or negedge rd_rst_n)
    if (!rd_rst_n) begin
      rbin  <= 0;
      rgray <= 0;
      empty <= 1'b1;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
      empty <= empty_next;
    end

  // RAM read port (registered output, updates on an accepted read).
  always @(posedge rd_clk)
    if (rd_en && !empty)
      dout <= mem[rbin[AW-1:0]];

  // Synchronize the WRITE Gray pointer into the READ domain.
  always @(posedge rd_clk or negedge rd_rst_n)
    if (!rd_rst_n) begin
      wgray_rd1 <= 0;
      wgray_rd2 <= 0;
    end else begin
      wgray_rd1 <= wgray;
      wgray_rd2 <= wgray_rd1;
    end

endmodule
