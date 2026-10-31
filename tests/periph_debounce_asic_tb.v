`timescale 1ns/1ps
module periph_debounce_asic_tb;
  reg clk = 0;
  reg rst_ni = 0;
  reg [3:0] btn = 0;
  wire [31:0] rdata;
  wire [3:0] leds;
  wire [6:0] seg1, seg2;

  always #5 clk = ~clk;

  // A short threshold makes the ASIC override test fast while exercising the
  // exact same parameter and comparison used by asic_top (100000 cycles).
  pochoco_periph #(.DebounceCycles(8)) dut (
    .clk_i(clk), .rst_ni(rst_ni), .sel_i(1'b0), .req_i(1'b0),
    .we_i(1'b0), .addr_i(8'b0), .wdata_i(32'b0), .be_i(4'b0),
    .rdata_o(rdata), .leds_o(leds), .btn_i(btn),
    .seg1_o(seg1), .seg2_o(seg2)
  );

  initial begin
    #20; rst_ni = 1;
    @(negedge clk); btn = 4'b0101;
    // Two synchronizer stages plus candidate capture precede the stable count.
    repeat (9) @(negedge clk);
    if (dut.btn_q !== 4'b0000)
      $fatal(1, "debounce accepted input before configured threshold");
    repeat (2) @(negedge clk);
    if (dut.btn_q !== 4'b0101)
      $fatal(1, "debounce did not accept input at configured threshold");
    $display("PASS parametrized ASIC debounce threshold");
    $finish;
  end
endmodule
