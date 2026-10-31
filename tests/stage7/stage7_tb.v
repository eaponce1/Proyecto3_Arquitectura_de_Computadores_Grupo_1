`timescale 1ns/1ps

module stage7_tb;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg [3:0] injected_btn = 4'b0;
  integer sim_cycle = 0;
  integer mismatch_count = 0;
  integer target_cycle;
  integer response_cycles [0:9];
  integer round;
  reg [3:0] target;
  reg [3:0] wrong;

  wire [3:0] rtl_leds, gate_leds;
  wire [6:0] rtl_seg1, rtl_seg2, gate_seg1, gate_seg2;
  wire rtl_miso, gate_miso;

  asic_top #(.MemoryArchitecture(1)) rtl (
    .clk_i(clk), .rst_ni(rst_n), .btn_i(4'b0), .leds_o(rtl_leds),
    .seg1_n_o(rtl_seg1), .seg2_n_o(rtl_seg2),
    .spi_sclk_i(1'b0), .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1),
    .spi_miso_o(rtl_miso)
  );

  asic_top_gate gate (
    .clk_i(clk), .rst_ni(rst_n), .btn_i(4'b0), .leds_o(gate_leds),
    .seg1_n_o(gate_seg1), .seg2_n_o(gate_seg2),
    .spi_sclk_i(1'b0), .spi_mosi_i(1'b0), .spi_cs_n_i(1'b1),
    .spi_miso_o(gate_miso)
  );

  wire [7:0] rtl_digit = rtl.u_pochoco_soc.u_periph.digit_q;
  wire [3:0] rtl_score = rtl.u_pochoco_soc.u_core.g_asic_regfile.u_rf.bank_a[8][3:0];
  wire [7:0] gate_digit = {
    gate.\u_pochoco_soc.u_periph.digit_q[7] ,
    gate.\u_pochoco_soc.u_periph.digit_q[6] ,
    gate.\u_pochoco_soc.u_periph.digit_q[5] ,
    gate.\u_pochoco_soc.u_periph.digit_q[4] ,
    gate.\u_pochoco_soc.u_periph.digit_q[3] ,
    gate.\u_pochoco_soc.u_periph.digit_q[2] ,
    gate.\u_pochoco_soc.u_periph.digit_q[1] ,
    gate.\u_pochoco_soc.u_periph.digit_q[0] 
  };
  wire [3:0] gate_score = {
    gate.\u_pochoco_soc.u_core.g_asic_regfile.u_rf.bank_a[8][3] ,
    gate.\u_pochoco_soc.u_core.g_asic_regfile.u_rf.bank_a[8][2] ,
    gate.\u_pochoco_soc.u_core.g_asic_regfile.u_rf.bank_a[8][1] ,
    gate.\u_pochoco_soc.u_core.g_asic_regfile.u_rf.bank_a[8][0] 
  };

  always #5 clk = ~clk;
  always @(posedge clk) sim_cycle = sim_cycle + 1;

  // Inject at the debouncer output. Icarus evaluates the RHS of a procedural
  // force once, so reapply every vector explicitly whenever the stimulus
  // changes. Both implementations still receive the same vector/cycle.
  task set_injected_button;
    input [3:0] mask;
    begin
      injected_btn = mask;
      force rtl.u_pochoco_soc.u_periph.btn_q = mask;
      force gate.\u_pochoco_soc.u_periph.btn_q[0]  = mask[0];
      force gate.\u_pochoco_soc.u_periph.btn_q[1]  = mask[1];
      force gate.\u_pochoco_soc.u_periph.btn_q[2]  = mask[2];
      force gate.\u_pochoco_soc.u_periph.btn_q[3]  = mask[3];
    end
  endtask

  // Cycle-accurate automatic comparison, including score and raw display data.
  always @(negedge clk) begin
    if (rst_n) begin
      if ({rtl_leds, rtl_seg1, rtl_seg2, rtl_digit, rtl_score, rtl_miso} !==
          {gate_leds, gate_seg1, gate_seg2, gate_digit, gate_score, gate_miso}) begin
        mismatch_count = mismatch_count + 1;
        $display("MISMATCH|cycle=%0d|rtl_led=%h|gate_led=%h|rtl_digit=%h|gate_digit=%h|rtl_score=%0d|gate_score=%0d",
                 sim_cycle, rtl_leds, gate_leds, rtl_digit, gate_digit,
                 rtl_score, gate_score);
        $fatal(1, "RTL/netlist divergence");
      end
    end
  end

  task automatic wait_cycles;
    input integer count;
    integer j;
    begin
      for (j = 0; j < count; j = j + 1) @(posedge clk);
    end
  endtask

  task automatic pulse_button;
    input [3:0] mask;
    begin
      @(negedge clk);
      set_injected_button(mask);
      wait_cycles(20);
      @(negedge clk);
      set_injected_button(4'b0);
    end
  endtask

  task automatic wait_for_all_leds;
    begin
      while (rtl_leds !== 4'hf) @(negedge clk);
    end
  endtask

  task automatic wait_for_target;
    begin
      while (!(rtl_leds == 4'h1 || rtl_leds == 4'h2 ||
               rtl_leds == 4'h4 || rtl_leds == 4'h8)) @(negedge clk);
      target = rtl_leds;
      target_cycle = sim_cycle;
    end
  endtask

  initial begin
    set_injected_button(4'b0);
    if ($test$plusargs("GATE_VCD")) begin
      $dumpfile("tests/stage7/evidence/post_synth.vcd");
    end else begin
      $dumpfile("tests/stage7/evidence/rtl.vcd");
    end
    $dumpvars(0, clk, rst_n, injected_btn, sim_cycle,
                 rtl_leds, gate_leds, rtl_seg1, rtl_seg2,
                 gate_seg1, gate_seg2, rtl_digit, gate_digit,
                 rtl_score, gate_score, mismatch_count);

    wait_cycles(8);
    @(negedge clk);
    rst_n = 1'b1;

    // Warmup: four LEDs, scaled 300-cycle wait, any button accepted.
    wait_for_all_leds();
    $display("CHECKPOINT|warmup|cycle=%0d|leds=%h", sim_cycle, rtl_leds);
    wait_cycles(360);
    pulse_button(4'h1);

    // Test B first: wrong response must show EE and leave score at zero.
    wait_for_target();
    wait_cycles(37);
    wrong = (target == 4'h1) ? 4'h2 : 4'h1;
    pulse_button(wrong);
    while (rtl_digit !== 8'hee) @(negedge clk);
    if (rtl_score !== 0 || gate_score !== 0)
      $fatal(1, "incorrect press changed score");
    wait_for_all_leds();
    if (rtl_score !== 0 || gate_score !== 0)
      $fatal(1, "incorrect press advanced the completed-round count");
    $display("RESULT|B|target=%h|pressed=%h|response_cycles=37|rtl_score=%0d|gate_score=%0d|display=ee|state=round_restarted",
             target, wrong, rtl_score, gate_score);

    // Ten correct rounds. Round 1 is also Test A.
    for (round = 0; round < 10; round = round + 1) begin
      wait_for_all_leds();
      wait_for_target();
      response_cycles[round] = 47 + round * 7;
      wait_cycles(response_cycles[round]);
      pulse_button(target);
      while (rtl_score !== round + 1) @(negedge clk);
      $display("RESULT|ROUND%0d|target=%h|response_cycles=%0d|rtl_score=%0d|gate_score=%0d|rtl_display=%02h|gate_display=%02h|match=yes",
               round + 1, target, response_cycles[round], rtl_score,
               gate_score, rtl_digit, gate_digit);
      if (round == 0)
        $display("RESULT|A|target=%h|response_cycles=%0d|rtl_cycles=%0d|gate_cycles=%0d|rtl_score=1|gate_score=1|state=round_complete",
                 target, response_cycles[round], response_cycles[round],
                 response_cycles[round]);
    end

    while (rtl_leds !== 4'h0) @(negedge clk);
    wait_cycles(20);
    if (rtl_score !== 10 || gate_score !== 10)
      $fatal(1, "ten correct rounds were not retained");
    if (mismatch_count !== 0)
      $fatal(1, "cycle comparison recorded mismatches");
    $display("RESULT|C|rounds=10|rtl_score=%0d|gate_score=%0d|rtl_average=%02h|gate_average=%02h|mismatches=%0d|state=hang",
             rtl_score, gate_score, rtl_digit, gate_digit, mismatch_count);
    $display("PASS|stage7|cycles=%0d", sim_cycle);
    $finish;
  end

  initial begin
    wait_cycles(100000);
    $fatal(1, "stage7 watchdog expired");
  end
endmodule
