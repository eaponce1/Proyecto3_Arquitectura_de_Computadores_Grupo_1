// ASIC integration wrapper for Proyecto 3.
// Reset is active-low and must be driven by the ASIC reset infrastructure.
// The seven-segment outputs retain the active-low polarity used by Project 2.
module asic_top #(
  // 1 = generated ROM + reduced RAM; 2 = unified flip-flop memory.
  parameter MemoryArchitecture = 1,
  // Stage 10 experiment.  Zero preserves the validated baseline register file.
  parameter UsePartitionedRegFile = 0,
  // 10 ms at the mandatory ASIC clock period of 100 ns (10 MHz).
  parameter integer DebounceCycles = 100000
) (
  input  wire       clk_i,
  input  wire       rst_ni,

  input  wire [3:0] btn_i,
  output wire [3:0] leds_o,
  output wire [6:0] seg1_n_o,
  output wire [6:0] seg2_n_o,

  input  wire       spi_sclk_i,
  input  wire       spi_mosi_i,
  input  wire       spi_cs_n_i,
  output wire       spi_miso_o
);

  pochoco_soc #(
    .MemFile("sw/game.hex"),
    .MemoryArchitecture(MemoryArchitecture),
    .UsePartitionedRegFile(UsePartitionedRegFile),
    .DebounceCycles(DebounceCycles)
  ) u_pochoco_soc (
    .i_Clk          (clk_i),
    .i_Rst_ni       (rst_ni),
    .o_LED          (leds_o),
    .i_Switch       (btn_i),
    .o_Segment1_A   (seg1_n_o[0]),
    .o_Segment1_B   (seg1_n_o[1]),
    .o_Segment1_C   (seg1_n_o[2]),
    .o_Segment1_D   (seg1_n_o[3]),
    .o_Segment1_E   (seg1_n_o[4]),
    .o_Segment1_F   (seg1_n_o[5]),
    .o_Segment1_G   (seg1_n_o[6]),
    .o_Segment2_A   (seg2_n_o[0]),
    .o_Segment2_B   (seg2_n_o[1]),
    .o_Segment2_C   (seg2_n_o[2]),
    .o_Segment2_D   (seg2_n_o[3]),
    .o_Segment2_E   (seg2_n_o[4]),
    .o_Segment2_F   (seg2_n_o[5]),
    .o_Segment2_G   (seg2_n_o[6]),
    .i_SPI_SCLK     (spi_sclk_i),
    .i_SPI_MOSI     (spi_mosi_i),
    .i_SPI_CS_n     (spi_cs_n_i),
    .o_SPI_MISO     (spi_miso_o)
  );

endmodule
