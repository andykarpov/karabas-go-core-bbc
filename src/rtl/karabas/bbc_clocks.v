`timescale 1ns / 1ps
`default_nettype wire
/*
 bbc_clocks.v

 The clocks of the BBC Micro core from CLK_50MHZ (the pin), as the two clocks of BeebFpga
 (clock_48 the machine, clock_27 the line doubler and HDMI; they are asynchronous in BeebFpga,
 the core crosses between them itself):

   clk_48: DCM_CLKGEN 50 * 24 / 25 = 48 MHz exactly (no PLL setting gives 48 from 50: VCO 400..1080 MHz,
           PFD >= 19 MHz) -> BUFG -> PLL A (x20, VCO 960 MHz, cleans the CLKFX jitter) /20: the machine,
           the SRAM, the MCU link, the DAC
   PLL B from 50 MHz (/2 x27, VCO 675 MHz):
     clk_27     /25  27 MHz: the doubled picture 720 x 576p50, the OSD, HDMI
     clk_135    /5   135 MHz and clk_135_n (180 degrees): the TMDS serialiser
     clk_8      /84  8.04 MHz: FT_CLK_OUT
 Both come from the one crystal: clk_48 / clk_27 = 16 / 9 exactly, so the 50 Hz of the Beeb and the
 50 Hz of the 864 x 625 output never drift apart (bbc_video_out keeps its own syncs anyway).
 locked: both PLLs.
*/
module bbc_clocks (
	input wire clk_in,
	output wire clk_48,
	output wire clk_27,
	output wire clk_135,
	output wire clk_135_n,
	output wire clk_8,
	output wire locked
);

wire clk_50_ibufg, clk_50_bufg;
IBUFG ibufg_50 (.I(clk_in), .O(clk_50_ibufg));
BUFG bufg_50 (.I(clk_50_ibufg), .O(clk_50_bufg));

wire fx, fx_buf, dcm_locked;
DCM_CLKGEN #(
	.CLKFX_MULTIPLY(24),
	.CLKFX_DIVIDE(25),
	.CLKFXDV_DIVIDE(2),
	.CLKFX_MD_MAX(0.96),
	.CLKIN_PERIOD(20.0),
	.SPREAD_SPECTRUM("NONE"),
	.STARTUP_WAIT("FALSE")
) dcm (
	.CLKIN(clk_50_bufg),
	.RST(1'b0),
	.FREEZEDCM(1'b0),
	.PROGCLK(1'b0),
	.PROGDATA(1'b0),
	.PROGEN(1'b0),
	.CLKFX(fx),
	.CLKFX180(),
	.CLKFXDV(),
	.LOCKED(dcm_locked),
	.PROGDONE(),
	.STATUS()
);
BUFG bufg_fx (.I(fx), .O(fx_buf));

wire [5:0] pll_a_clk;
wire pll_a_locked;
kg_pll #(
	.CLKIN_PERIOD(20.833),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(20),
	.CLKOUT0_DIVIDE(20),
	.CLKOUT1_DIVIDE(20),  // the unused outputs at a legal frequency
	.CLKOUT2_DIVIDE(20),
	.CLKOUT3_DIVIDE(20),
	.CLKOUT4_DIVIDE(20),
	.CLKOUT5_DIVIDE(20),
	.IBUFG(0),
	.BUFG_MASK(6'b000001)
) pll_a (
	.clk_in(fx_buf),
	.rst(!dcm_locked),
	.clk_out(pll_a_clk),
	.locked(pll_a_locked)
);

wire [5:0] pll_b_clk;
wire pll_b_locked;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(2),
	.CLKFBOUT_MULT(27),
	.CLKOUT0_DIVIDE(25),
	.CLKOUT1_DIVIDE(5),
	.CLKOUT2_DIVIDE(5),
	.CLKOUT2_PHASE(180.0),
	.CLKOUT3_DIVIDE(84),
	.CLKOUT4_DIVIDE(25),
	.CLKOUT5_DIVIDE(25),
	.IBUFG(0),
	.BUFG_MASK(6'b001111)
) pll_b (
	.clk_in(clk_50_bufg),
	.rst(1'b0),
	.clk_out(pll_b_clk),
	.locked(pll_b_locked)
);

assign clk_48 = pll_a_clk[0];
assign clk_27 = pll_b_clk[0];
assign clk_135 = pll_b_clk[1];
assign clk_135_n = pll_b_clk[2];
assign clk_8 = pll_b_clk[3];
assign locked = pll_a_locked & pll_b_locked;

endmodule
