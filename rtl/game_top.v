module game_top (
  input  wire       i_Clk,

  output wire [3:0] o_LED,
  input  wire [3:0] i_Switch,

  output wire       o_Segment1_A, o_Segment1_B, o_Segment1_C, o_Segment1_D,
  output wire       o_Segment1_E, o_Segment1_F, o_Segment1_G,

  output wire       o_Segment2_A, o_Segment2_B, o_Segment2_C, o_Segment2_D,
  output wire       o_Segment2_E, o_Segment2_F, o_Segment2_G,

  input  wire       i_SPI_SCLK,
  input  wire       i_SPI_MOSI,
  input  wire       i_SPI_CS_n,
  output wire       o_SPI_MISO
);

  // FPGA-only power-on delay retained from the Project 2 integration.
  // The ASIC wrapper supplies its reset from an external reset network.
  reg [11:0] por_cnt = 12'b0;
  always @(posedge i_Clk) begin
    if (!por_cnt[11]) por_cnt <= por_cnt + 12'd1;
  end

  pochoco_soc #(
    .MemFile("sw/game.hex")
  ) u_pochoco (
    .i_Clk(i_Clk),
    .i_Rst_ni(por_cnt[11]),

    .o_LED(o_LED),
    .i_Switch(i_Switch),

    .o_Segment1_A(o_Segment1_A),
    .o_Segment1_B(o_Segment1_B),
    .o_Segment1_C(o_Segment1_C),
    .o_Segment1_D(o_Segment1_D),
    .o_Segment1_E(o_Segment1_E),
    .o_Segment1_F(o_Segment1_F),
    .o_Segment1_G(o_Segment1_G),

    .o_Segment2_A(o_Segment2_A),
    .o_Segment2_B(o_Segment2_B),
    .o_Segment2_C(o_Segment2_C),
    .o_Segment2_D(o_Segment2_D),
    .o_Segment2_E(o_Segment2_E),
    .o_Segment2_F(o_Segment2_F),
    .o_Segment2_G(o_Segment2_G),

    .i_SPI_SCLK(i_SPI_SCLK),
    .i_SPI_MOSI(i_SPI_MOSI),
    .i_SPI_CS_n(i_SPI_CS_n),
    .o_SPI_MISO(o_SPI_MISO)
  );

endmodule
