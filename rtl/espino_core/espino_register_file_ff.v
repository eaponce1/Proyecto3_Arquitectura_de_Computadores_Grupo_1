// ASIC replacement for the iCE40 SB_RAM40_4K register bank.
// Two copies preserve Espino's synchronous two-read-port timing.
module espino_register_file_ff (
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
  reg [31:0] bank_a [0:15];
  reg [31:0] bank_b [0:15];
  integer i;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_a_o <= 32'b0;
      rdata_b_o <= 32'b0;
      for (i = 0; i < 16; i = i + 1) begin
        bank_a[i] <= 32'b0;
        bank_b[i] <= 32'b0;
      end
    end else begin
      rdata_a_o <= (raddr_a_i == 4'd0) ? 32'b0 : bank_a[raddr_a_i];
      rdata_b_o <= (raddr_b_i == 4'd0) ? 32'b0 : bank_b[raddr_b_i];
      if (we_i && waddr_i != 4'd0) begin
        bank_a[waddr_i] <= wdata_i;
        bank_b[waddr_i] <= wdata_i;
      end
    end
  end
endmodule
