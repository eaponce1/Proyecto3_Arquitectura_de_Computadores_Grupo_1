`timescale 1ns/1ps

// External-interface-only comparison for the final, flattened Stage 21 netlist.
// No synthesized hierarchy, register-file names, or internal forces are used.
module stage21_external_tb;
  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;
  reg [3:0] btn_i = 4'b0000;
  reg spi_sclk_i = 1'b0;
  reg spi_mosi_i = 1'b0;
  reg spi_cs_n_i = 1'b1;

  wire [3:0] rtl_leds_o, gate_leds_o;
  wire [6:0] rtl_seg1_n_o, gate_seg1_n_o;
  wire [6:0] rtl_seg2_n_o, gate_seg2_n_o;
  wire rtl_spi_miso_o, gate_spi_miso_o;

  integer cycle;
  integer mismatch_count;
  integer observed_button_cycles;

  asic_top #(.MemoryArchitecture(1)) rtl (
    .clk_i(clk_i), .rst_ni(rst_ni), .btn_i(btn_i), .leds_o(rtl_leds_o),
    .seg1_n_o(rtl_seg1_n_o), .seg2_n_o(rtl_seg2_n_o),
    .spi_sclk_i(spi_sclk_i), .spi_mosi_i(spi_mosi_i),
    .spi_cs_n_i(spi_cs_n_i), .spi_miso_o(rtl_spi_miso_o)
  );

  asic_top_gate gate (
    .clk_i(clk_i), .rst_ni(rst_ni), .btn_i(btn_i), .leds_o(gate_leds_o),
    .seg1_n_o(gate_seg1_n_o), .seg2_n_o(gate_seg2_n_o),
    .spi_sclk_i(spi_sclk_i), .spi_mosi_i(spi_mosi_i),
    .spi_cs_n_i(spi_cs_n_i), .spi_miso_o(gate_spi_miso_o)
  );

  always #5 clk_i = ~clk_i;
  always @(posedge clk_i) cycle = cycle + 1;

  // Compare only observable top-level outputs. This remains valid after Yosys
  // flattening and is deliberately independent of implementation hierarchy.
  always @(negedge clk_i) begin
    if (rst_ni &&
        ({rtl_leds_o, rtl_seg1_n_o, rtl_seg2_n_o, rtl_spi_miso_o} !==
         {gate_leds_o, gate_seg1_n_o, gate_seg2_n_o, gate_spi_miso_o})) begin
      mismatch_count = mismatch_count + 1;
      $display("MISMATCH|cycle=%0d|rtl_led=%h|gate_led=%h|rtl_seg1=%h|gate_seg1=%h|rtl_seg2=%h|gate_seg2=%h|rtl_miso=%b|gate_miso=%b",
               cycle, rtl_leds_o, gate_leds_o, rtl_seg1_n_o, gate_seg1_n_o,
               rtl_seg2_n_o, gate_seg2_n_o, rtl_spi_miso_o, gate_spi_miso_o);
    end
  end

  task automatic wait_cycles(input integer count);
    integer i;
    begin
      for (i = 0; i < count; i = i + 1) @(posedge clk_i);
    end
  endtask

  task automatic external_button(input [3:0] mask, input integer count);
    begin
      @(negedge clk_i);
      btn_i = mask;
      observed_button_cycles = observed_button_cycles + count;
      wait_cycles(count);
      @(negedge clk_i);
      btn_i = 4'b0000;
    end
  endtask

  initial begin
    cycle = 0;
    mismatch_count = 0;
    observed_button_cycles = 0;
    $dumpfile("reports/stage21/stage21_external.vcd");
    $dumpvars(0, stage21_external_tb);

    // rst_ni is active-low in both the RTL wrapper and the synthesized port.
    wait_cycles(8);
    @(negedge clk_i);
    rst_ni = 1'b1;

    // Common external stimuli: reset release, idle, then a short button pulse.
    // The final ASIC netlist contains the real 100000-cycle debouncer; this
    // pulse is intentionally not treated as a completed game response.
    wait_cycles(64);
    external_button(4'b0001, 8);
    wait_cycles(128);

    if (mismatch_count != 0)
      $fatal(1, "RTL/netlist observable mismatch count=%0d", mismatch_count);

    $display("PASS|stage21_external_smoke|cycles=%0d|button_cycles=%0d|mismatches=%0d",
             cycle, observed_button_cycles, mismatch_count);
    $finish;
  end

  initial begin
    wait_cycles(1000);
    $fatal(1, "stage21 external smoke watchdog expired");
  end
endmodule
