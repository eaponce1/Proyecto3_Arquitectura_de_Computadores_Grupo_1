`timescale 1ns/1ps
module asic_game_smoke_tb #(parameter integer ARCH = 1);
  reg clk = 0, rst_n = 0;
  wire [3:0] leds;
  wire [6:0] seg1, seg2;
  wire miso;
  always #5 clk = ~clk;

  asic_top #(.MemoryArchitecture(ARCH)) dut (
    .clk_i(clk), .rst_ni(rst_n), .btn_i(4'b0), .leds_o(leds),
    .seg1_n_o(seg1), .seg2_n_o(seg2), .spi_sclk_i(1'b0),
    .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1), .spi_miso_o(miso)
  );

  initial begin
    #22 rst_n = 1;
    repeat (500) @(posedge clk);
    if (leds !== 4'hf) $fatal(1, "game did not enter warmup");
    if (dut.u_pochoco_soc.u_core.u_if.pc_q == 0) $fatal(1, "core did not execute game ROM");
    $display("PASS ASIC game smoke, architecture %0d", ARCH);
    $finish;
  end
endmodule
