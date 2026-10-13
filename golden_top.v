// ============================================================================
// Copyright (c) 2025 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development
//   Kits made by Terasic.  Other use of this code, including the selling
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use
//   or functionality of this code.
//
// ============================================================================
//
//  Terasic Technologies Inc
//  No.80, Fenggong Rd., Hukou Township, Hsinchu County 303035. Taiwan
//
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Mon Aug 18 13:47:53 2025
// ============================================================================

module golden_top(

      ///////// CLOCK /////////
      input              CLOCK0_50,
      input              CLOCK1_50,

      ///////// KEY /////////
      input    [ 3: 0]   KEY, //BUTTON is Low-Active

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LED /////////
      output   [ 9: 0]   LEDR, //LED is Low-Active

      ///////// Seg7 /////////
      output   [ 6: 0]   HEX0,
      output   [ 6: 0]   HEX1,
      output   [ 6: 0]   HEX2,
      output   [ 6: 0]   HEX3,
      output   [ 6: 0]   HEX4,
      output   [ 6: 0]   HEX5,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [31: 0]   DRAM_DQ,
      output             DRAM_CS_n,
      output             DRAM_WE_n,
      output             DRAM_CAS_n,
      output             DRAM_RAS_n,
      output   [ 3: 0]   DRAM_DQM,

      ///////// HDMI /////////
      output             HDMI_TX_CLK,
      output             HDMI_TX_HS,
      output             HDMI_TX_VS,
      output   [23: 0]   HDMI_TX_D,
      output             HDMI_TX_DE,
      input              HDMI_TX_INT,
      inout              HDMI_LRCLK,
      inout              HDMI_MCLK,
      inout              HDMI_SCLK,
      inout              HDMI_I2S0,

      ///////// UART /////////
      output             UART_TX,
      input              UART_RX,

      ///////// I2C for HDMI and ADC /////////
      inout              I2C_SCL,
      inout              I2C_SDA,

      ///////// GPIO /////////
      inout    [35: 0]   GPIO_D

);


//=======================================================
//  REG/WIRE declarations
//=======================================================

wire ninit_done;
wire reset_request_n = KEY[0] & ~ninit_done;

reg reset_sync_1;
reg reset_sync_2;
wire uart_reset_n = reset_sync_2;

always @(posedge CLOCK0_50 or negedge reset_request_n) begin
    if (!reset_request_n) begin
        reset_sync_1 <= 1'b0;
        reset_sync_2 <= 1'b0;
    end
    else begin
        reset_sync_1 <= 1'b1;
        reset_sync_2 <= reset_sync_1;
    end
end

//uart Declarations---------------------------------------



//=======================================================
//  Structural coding
//=======================================================
reset_release reset_release_unit(
	.ninit_done(ninit_done)
);

uart_processing_top uart_processing_top_unit(
	.clock(CLOCK0_50),
	.reset_n(uart_reset_n),
	.uart_rx(UART_RX),

	.uart_tx(UART_TX)
);

endmodule
