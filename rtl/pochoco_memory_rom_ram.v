// ASIC memory architecture 1: generated combinational program ROM plus one
// data word.  The read response remains registered to match pochoco_ram.v.
module pochoco_memory_rom_ram #(
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
  output wire        init_done_o
);
  wire [31:0] rom_rdata;
  reg [31:0] data_q;
  game_rom u_game_rom (.addr_i(a_addr_i), .rdata_o(rom_rdata));
  assign init_done_o = 1'b1;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      a_rdata_o <= 32'b0;
      b_rdata_o <= 32'b0;
      data_q <= 32'b0;
    end else begin
      if (a_req_i) a_rdata_o <= rom_rdata;
      b_rdata_o <= (b_addr_i == DataAddr) ? data_q : 32'b0;
      if (b_req_i && b_we_i && b_addr_i == DataAddr) begin
        if (b_be_i[0]) data_q[7:0]   <= b_wdata_i[7:0];
        if (b_be_i[1]) data_q[15:8]  <= b_wdata_i[15:8];
        if (b_be_i[2]) data_q[23:16] <= b_wdata_i[23:16];
        if (b_be_i[3]) data_q[31:24] <= b_wdata_i[31:24];
      end
    end
  end
endmodule
