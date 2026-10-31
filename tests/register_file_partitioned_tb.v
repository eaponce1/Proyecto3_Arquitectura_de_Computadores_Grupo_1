`timescale 1ns/1ps
module register_file_partitioned_tb;
  reg clk = 0;
  reg rst_n = 0;
  reg [3:0] raddr_a = 0, raddr_b = 0, waddr = 0;
  reg [31:0] wdata = 0;
  reg we = 0;
  wire [31:0] base_a, base_b, part_a, part_b;
  integer i;

  always #5 clk = ~clk;

  espino_register_file_ff base (
    clk, rst_n, raddr_a, base_a, raddr_b, base_b,
    waddr, wdata, we
  );
  espino_register_file_ff_partitioned part (
    clk, rst_n, raddr_a, part_a, raddr_b, part_b,
    waddr, wdata, we
  );

  task check_equal;
    begin
      #1;
      if ({base_a, base_b} !== {part_a, part_b})
        $fatal(1, "register-file mismatch: base=%h/%h part=%h/%h",
               base_a, base_b, part_a, part_b);
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1;

    // Populate every architectural register and compare the synchronous
    // outputs on every cycle, including simultaneous read/write activity.
    for (i = 0; i < 16; i = i + 1) begin
      @(negedge clk);
      we = 1;
      waddr = i[3:0];
      wdata = 32'h51a00000 ^ (i * 32'h01020408);
      raddr_a = (i + 3) & 15;
      raddr_b = (i + 9) & 15;
      @(posedge clk);
      check_equal();
    end

    we = 0;
    for (i = 0; i < 64; i = i + 1) begin
      @(negedge clk);
      raddr_a = (i * 5 + 1) & 15;
      raddr_b = (i * 7 + 4) & 15;
      @(posedge clk);
      check_equal();
    end

    // x0 must remain hard-wired to zero despite the attempted write above.
    @(negedge clk);
    raddr_a = 0;
    raddr_b = 0;
    @(posedge clk);
    check_equal();
    if (part_a !== 0 || part_b !== 0)
      $fatal(1, "partitioned x0 is not zero");
    $display("PASS partitioned register file: cycle-exact baseline equivalence");
    $finish;
  end
endmodule
