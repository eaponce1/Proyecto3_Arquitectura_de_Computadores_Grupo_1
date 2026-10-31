// Etapa 4 ASIC experiment: branch comparisons run in parallel with the
// add/sub datapath, keeping the instruction decode out of the carry chain.
// The FPGA ALU in rtl/espino_core/espino_alu.v remains unchanged.
module espino_alu (
  input  wire [3:0]  operator_i,
  input  wire [31:0] operand_a_i,
  input  wire [31:0] operand_b_i,
  output reg  [31:0] result_o,
  output reg         cmp_result_o
);
  localparam [3:0] ALU_ADD  = 4'd0,
                   ALU_SUB  = 4'd1,
                   ALU_XOR  = 4'd2,
                   ALU_OR   = 4'd3,
                   ALU_AND  = 4'd4,
                   ALU_SLL  = 4'd5,
                   ALU_SRL  = 4'd6,
                   ALU_SRA  = 4'd7,
                   ALU_SLT  = 4'd8,
                   ALU_SLTU = 4'd9,
                   ALU_EQ   = 4'd10,
                   ALU_NE   = 4'd11,
                   ALU_LT   = 4'd12,
                   ALU_GE   = 4'd13,
                   ALU_LTU  = 4'd14,
                   ALU_GEU  = 4'd15;

  wire sub_mode = (operator_i != ALU_ADD);
  wire [31:0] b_mux = sub_mode ? ~operand_b_i : operand_b_i;
  wire [31:0] adder_res = operand_a_i + b_mux + {31'b0, sub_mode};

  // Independent comparators let branch decode select a completed result.
  wire cmp_eq  = (operand_a_i == operand_b_i);
  wire cmp_lt  = ($signed(operand_a_i) < $signed(operand_b_i));
  wire cmp_ltu = (operand_a_i < operand_b_i);

  always @* begin
    case (operator_i)
      ALU_EQ:  cmp_result_o =  cmp_eq;
      ALU_NE:  cmp_result_o = ~cmp_eq;
      ALU_LT:  cmp_result_o =  cmp_lt;
      ALU_GE:  cmp_result_o = ~cmp_lt;
      ALU_LTU: cmp_result_o =  cmp_ltu;
      ALU_GEU: cmp_result_o = ~cmp_ltu;
      default: cmp_result_o = 1'b0;
    endcase
  end

  always @* begin
    case (operator_i)
      ALU_ADD:  result_o = adder_res;
      ALU_SUB:  result_o = adder_res;
      ALU_XOR:  result_o = operand_a_i ^ operand_b_i;
      ALU_OR:   result_o = operand_a_i | operand_b_i;
      ALU_AND:  result_o = operand_a_i & operand_b_i;
      ALU_SLT:  result_o = {31'b0, cmp_lt};
      ALU_SLTU: result_o = {31'b0, cmp_ltu};
      default:  result_o = adder_res;  // Same default as FPGA ALU.
    endcase
  end
endmodule
