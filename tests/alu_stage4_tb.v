`timescale 1ns/1ps
module alu_stage4_tb;
  reg [3:0] op;
  reg [31:0] a, b;
  wire [31:0] result;
  wire cmp;
  reg [31:0] expected_result;
  reg expected_cmp;
  integer i, j;

  espino_alu dut (.operator_i(op), .operand_a_i(a), .operand_b_i(b),
                  .result_o(result), .cmp_result_o(cmp));

  initial begin
    for (i = 0; i < 1000; i = i + 1) begin
      a = $random;
      b = $random;
      for (j = 0; j < 16; j = j + 1) begin
        op = j[3:0];
        expected_result = a - b;
        expected_cmp = 1'b0;
        case (j)
          0: expected_result = a + b;
          2: expected_result = a ^ b;
          3: expected_result = a | b;
          4: expected_result = a & b;
          8: expected_result = {31'b0, ($signed(a) < $signed(b))};
          9: expected_result = {31'b0, (a < b)};
        endcase
        case (j)
          10: expected_cmp = (a == b);
          11: expected_cmp = (a != b);
          12: expected_cmp = ($signed(a) < $signed(b));
          13: expected_cmp = ($signed(a) >= $signed(b));
          14: expected_cmp = (a < b);
          15: expected_cmp = (a >= b);
        endcase
        #1;
        if (result !== expected_result || cmp !== expected_cmp)
          $fatal(1, "ALU mismatch i=%0d op=%0d a=%h b=%h result=%h/%h cmp=%b/%b",
                 i, j, a, b, result, expected_result, cmp, expected_cmp);
      end
    end
    $display("PASS ALU arithmetic and comparisons: 16000 cases");
    $finish;
  end
endmodule
