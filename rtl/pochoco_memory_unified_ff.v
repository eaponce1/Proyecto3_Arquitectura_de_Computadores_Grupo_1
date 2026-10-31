// ASIC memory architecture 2: one flip-flop array for program and data.
// Reset loads the generated program over ProgramWords+1 clock cycles; the
// core remains reset until init_done_o is asserted by pochoco_soc.
module pochoco_memory_unified_ff #(
  parameter integer ProgramWords = 143,
  parameter [31:0] DataAddr = 32'h0000_07fc
) (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire        a_req_i,
  input  wire [31:0] a_addr_i,
  output reg  [31:0] a_rdata_o,
  input  wire        b_req_i,
  input  wire        b_we_i,
  input  wire [3:0]  b_be_i,
  input  wire [31:0] b_addr_i,
  input  wire [31:0] b_wdata_i,
  output reg  [31:0] b_rdata_o,
  output reg         init_done_o
);
  localparam integer DataIndex = ProgramWords;
  reg [31:0] mem [0:DataIndex];
  reg [7:0] init_index_q;
  wire [31:0] init_word;
  wire [31:0] a_word = a_addr_i >> 2;
  game_rom u_game_rom (.addr_i({22'b0, init_index_q, 2'b00}), .rdata_o(init_word));

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      init_index_q <= 8'd0;
      init_done_o  <= 1'b0;
      a_rdata_o    <= 32'b0;
      b_rdata_o    <= 32'b0;
    end else if (!init_done_o) begin
      if (init_index_q < ProgramWords) begin
        mem[init_index_q] <= init_word;
        init_index_q <= init_index_q + 8'd1;
      end else begin
        mem[DataIndex] <= 32'b0;
        init_done_o <= 1'b1;
      end
    end else begin
      if (a_req_i) a_rdata_o <= (a_word < ProgramWords) ? mem[a_word] : 32'b0;
      b_rdata_o <= (b_addr_i == DataAddr) ? mem[DataIndex] : 32'b0;
      if (b_req_i && b_we_i && b_addr_i == DataAddr) begin
        if (b_be_i[0]) mem[DataIndex][7:0]   <= b_wdata_i[7:0];
        if (b_be_i[1]) mem[DataIndex][15:8]  <= b_wdata_i[15:8];
        if (b_be_i[2]) mem[DataIndex][23:16] <= b_wdata_i[23:16];
        if (b_be_i[3]) mem[DataIndex][31:24] <= b_wdata_i[31:24];
      end
    end
  end
endmodule
