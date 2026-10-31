// Stage 10 experiment: the same 16 x 32-bit, two-read-port register file as
// espino_register_file_ff, split into independent byte lanes.  The split
// deliberately prevents a single shared read decoder from driving all 32
// mux bits.  Reads remain synchronous and no pipeline stage is added.
module espino_register_file_ff_partitioned (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire [3:0]  raddr_a_i,
  output reg  [31:0] rdata_a_o,
  input  wire [3:0]  raddr_b_i,
  output reg  [31:0] rdata_b_o,
  input  wire [3:0]  waddr_i,
  input  wire [31:0] wdata_i,
  input  wire        we_i
);
  // Keeping separate memories is the optimization under test: each mapped
  // read decoder serves eight data bits instead of the complete 32-bit word.
  reg [7:0] bank_a0 [0:15];
  reg [7:0] bank_a1 [0:15];
  reg [7:0] bank_a2 [0:15];
  reg [7:0] bank_a3 [0:15];
  reg [7:0] bank_b0 [0:15];
  reg [7:0] bank_b1 [0:15];
  reg [7:0] bank_b2 [0:15];
  reg [7:0] bank_b3 [0:15];
  integer i;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_a_o <= 32'b0;
      rdata_b_o <= 32'b0;
      for (i = 0; i < 16; i = i + 1) begin
        bank_a0[i] <= 8'b0;
        bank_a1[i] <= 8'b0;
        bank_a2[i] <= 8'b0;
        bank_a3[i] <= 8'b0;
        bank_b0[i] <= 8'b0;
        bank_b1[i] <= 8'b0;
        bank_b2[i] <= 8'b0;
        bank_b3[i] <= 8'b0;
      end
    end else begin
      rdata_a_o <= (raddr_a_i == 4'd0) ? 32'b0 :
                   {bank_a3[raddr_a_i], bank_a2[raddr_a_i],
                    bank_a1[raddr_a_i], bank_a0[raddr_a_i]};
      rdata_b_o <= (raddr_b_i == 4'd0) ? 32'b0 :
                   {bank_b3[raddr_b_i], bank_b2[raddr_b_i],
                    bank_b1[raddr_b_i], bank_b0[raddr_b_i]};
      if (we_i && waddr_i != 4'd0) begin
        bank_a0[waddr_i] <= wdata_i[7:0];
        bank_a1[waddr_i] <= wdata_i[15:8];
        bank_a2[waddr_i] <= wdata_i[23:16];
        bank_a3[waddr_i] <= wdata_i[31:24];
        bank_b0[waddr_i] <= wdata_i[7:0];
        bank_b1[waddr_i] <= wdata_i[15:8];
        bank_b2[waddr_i] <= wdata_i[23:16];
        bank_b3[waddr_i] <= wdata_i[31:24];
      end
    end
  end
endmodule
