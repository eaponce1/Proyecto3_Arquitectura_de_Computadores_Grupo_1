`timescale 1ns/1ps

// Throughput benchmark. It deliberately does not dump VCD and does not use
// internal hierarchy. Define RTL_ONLY or GATE_ONLY for separate measurements.
module stage22_benchmark_tb;
  parameter integer BENCH_CYCLES = 100000;
  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;
  reg [3:0] btn_i = 4'b0;
  wire [3:0] rtl_leds, gate_leds;
  wire [6:0] rtl_seg1, gate_seg1, rtl_seg2, gate_seg2;
  wire rtl_miso, gate_miso;
  integer cycle = 0;
  integer mismatches = 0;

`ifndef GATE_ONLY
  asic_top #(.MemoryArchitecture(1)) rtl (
    .clk_i(clk_i), .rst_ni(rst_ni), .btn_i(btn_i), .leds_o(rtl_leds),
    .seg1_n_o(rtl_seg1), .seg2_n_o(rtl_seg2), .spi_sclk_i(1'b0),
    .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1), .spi_miso_o(rtl_miso));
`endif
`ifndef RTL_ONLY
  asic_top_gate gate (
    .clk_i(clk_i), .rst_ni(rst_ni), .btn_i(btn_i), .leds_o(gate_leds),
    .seg1_n_o(gate_seg1), .seg2_n_o(gate_seg2), .spi_sclk_i(1'b0),
    .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1), .spi_miso_o(gate_miso));
`endif

  always #5 clk_i = ~clk_i;
  always @(posedge clk_i) cycle = cycle + 1;

`ifndef GATE_ONLY
`ifndef RTL_ONLY
  always @(negedge clk_i) begin
    if (rst_ni && ({rtl_leds,rtl_seg1,rtl_seg2,rtl_miso} !==
                   {gate_leds,gate_seg1,gate_seg2,gate_miso}))
      mismatches = mismatches + 1;
  end
`endif
`endif

  initial begin
    repeat (8) @(posedge clk_i);
    @(negedge clk_i); rst_ni = 1'b1;
    repeat (BENCH_CYCLES) @(posedge clk_i);
    $display("BENCH|mode=%s|cycles=%0d|mismatches=%0d",
`ifdef RTL_ONLY
             "rtl",
`elsif GATE_ONLY
             "gate",
`else
             "paired",
`endif
             cycle, mismatches);
    $finish;
  end
endmodule
