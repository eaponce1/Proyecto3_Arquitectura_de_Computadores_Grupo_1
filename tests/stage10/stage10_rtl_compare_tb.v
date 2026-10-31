`timescale 1ns/1ps
module stage10_rtl_compare_tb;
  reg clk = 0;
  reg rst_n = 0;
  integer cycle = 0;
  integer mismatches = 0;
  integer round;
  integer response_cycles [0:9];
  reg [3:0] target, wrong;

  wire [3:0] base_leds, part_leds;
  wire [6:0] base_seg1, base_seg2, part_seg1, part_seg2;
  wire base_miso, part_miso;

  asic_top #(.MemoryArchitecture(1), .UsePartitionedRegFile(0)) baseline (
    .clk_i(clk), .rst_ni(rst_n), .btn_i(4'b0), .leds_o(base_leds),
    .seg1_n_o(base_seg1), .seg2_n_o(base_seg2),
    .spi_sclk_i(1'b0), .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1),
    .spi_miso_o(base_miso)
  );
  asic_top #(.MemoryArchitecture(1), .UsePartitionedRegFile(1)) partitioned (
    .clk_i(clk), .rst_ni(rst_n), .btn_i(4'b0), .leds_o(part_leds),
    .seg1_n_o(part_seg1), .seg2_n_o(part_seg2),
    .spi_sclk_i(1'b0), .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1),
    .spi_miso_o(part_miso)
  );

  wire [7:0] base_digit = baseline.u_pochoco_soc.u_periph.digit_q;
  wire [7:0] part_digit = partitioned.u_pochoco_soc.u_periph.digit_q;
  wire [3:0] base_score =
    baseline.u_pochoco_soc.u_core.g_asic_regfile.u_rf.bank_a[8][3:0];
  wire [3:0] part_score =
    partitioned.u_pochoco_soc.u_core.g_partitioned_regfile.u_rf.bank_a0[8][3:0];

  always #5 clk = ~clk;
  always @(posedge clk) cycle = cycle + 1;

  task set_button;
    input [3:0] mask;
    begin
      force baseline.u_pochoco_soc.u_periph.btn_q = mask;
      force partitioned.u_pochoco_soc.u_periph.btn_q = mask;
    end
  endtask
  task automatic wait_cycles;
    input integer count;
    integer j;
    begin for (j = 0; j < count; j = j + 1) @(posedge clk); end
  endtask
  task pulse_button;
    input [3:0] mask;
    begin
      @(negedge clk); set_button(mask); wait_cycles(20);
      @(negedge clk); set_button(0);
    end
  endtask
  task automatic wait_all_leds;
    begin while (base_leds !== 4'hf) @(negedge clk); end
  endtask
  task automatic wait_target;
    begin
      while (!(base_leds == 1 || base_leds == 2 ||
               base_leds == 4 || base_leds == 8)) @(negedge clk);
      target = base_leds;
    end
  endtask

  always @(negedge clk) if (rst_n) begin
    if ({base_leds,base_seg1,base_seg2,base_digit,base_score,base_miso} !==
        {part_leds,part_seg1,part_seg2,part_digit,part_score,part_miso}) begin
      mismatches = mismatches + 1;
      $fatal(1, "cycle %0d baseline/partitioned divergence", cycle);
    end
  end

  initial begin
    $dumpfile("tests/stage10/evidence/rtl_compare.vcd");
    $dumpvars(0, stage10_rtl_compare_tb);
    set_button(0);
    wait_cycles(8);
    @(negedge clk); rst_n = 1;
    wait_all_leds();
    wait_cycles(360);
    pulse_button(1);

    // Wrong press: the score must stay at zero and the round must restart.
    wait_target();
    wait_cycles(37);
    wrong = (target == 1) ? 2 : 1;
    pulse_button(wrong);
    while (base_digit !== 8'hee) @(negedge clk);
    if (base_score !== 0 || part_score !== 0) $fatal(1, "wrong press scored");
    wait_all_leds();
    $display("RESULT|B|cycle=%0d|score=0|display=ee|match=yes", cycle);

    for (round = 0; round < 10; round = round + 1) begin
      wait_all_leds();
      wait_target();
      response_cycles[round] = 47 + round * 7;
      wait_cycles(response_cycles[round]);
      pulse_button(target);
      while (base_score !== round + 1) @(negedge clk);
      $display("RESULT|ROUND%0d|response_cycles=%0d|score=%0d|match=yes",
               round + 1, response_cycles[round], base_score);
    end
    while (base_leds !== 0) @(negedge clk);
    wait_cycles(20);
    if (base_score !== 10 || part_score !== 10 || mismatches !== 0)
      $fatal(1, "ten-round comparison failed");
    $display("RESULT|C|rounds=10|average=%02h|mismatches=%0d|match=yes",
             base_digit, mismatches);
    $display("PASS stage10 RTL cycle comparison at cycle %0d", cycle);
    $finish;
  end

  initial begin
    wait_cycles(100000);
    $display("WATCHDOG|cycle=%0d|rst=%b|leds=%h/%h|pc=%h|instr=%h|digit=%h|score=%0d",
             cycle, rst_n, base_leds, part_leds,
             baseline.u_pochoco_soc.instr_addr,
             baseline.u_pochoco_soc.instr_rdata,
             base_digit, base_score);
    $fatal(1, "stage10 watchdog expired");
  end
endmodule
