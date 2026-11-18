`timescale 1ns / 1ps
`default_nettype wire
/*
 bbc_video_out.v

 720 x 576p50 (27 MHz, 864 x 625: the modeline "720x576 @ 50hz 27 720 732 796 864 576 581 586 625")
 from the line-doubled picture of bbc_micro_core (BeebFpga IncludeVGA: rgb2vga_scandoubler + linedelay
 on clock_27, 32 us lines, syncs high active), with syncs and de always present.

 As the HDMI block of BeebFpga (bbc_micro_core, HDMIIncluded): hcnt is 0 at the trailing edge of the
 hsync of the core, vcnt is 0 at the line start after the trailing edge of its vsync; the picture is
 hcnt 68..787 x vcnt 39..614, hsync hcnt 800..863, vsync vcnt 620..624.
 Unlike it, the counters also run on their own: hcnt wraps at 864 and vcnt at 625 when the core gives
 no sync (reset, a CRTC with the syncs off), so the output never stops; the doubler keeps 864-clock
 lines in any case, and a frame of the Beeb is 624 (progressive) or 625 (interlaced) lines.

 Out (registered, one clock after the counters): rgb 8 bits a colour (the 4 bits of the core twice),
 black outside de; hs / vs / de high active.
*/
module bbc_video_out (
	input wire clk,          // 27 MHz
	input wire [3:0] r_i,
	input wire [3:0] g_i,
	input wire [3:0] b_i,
	input wire hs_i,
	input wire vs_i,
	output reg [23:0] rgb = 24'd0,
	output reg hs = 1'b0,
	output reg vs = 1'b0,
	output reg de = 1'b0
);

localparam H_TOTAL = 864;
localparam H_DE_X = 68;
localparam H_DE_W = 720;
localparam H_SYNC_X = 800;
localparam V_TOTAL = 625;
localparam V_DE_Y = 39;
localparam V_DE_H = 576;
localparam V_SYNC_Y = 620;

reg hs_d = 1'b0, vs_line = 1'b0, vs_seen = 1'b0;
reg [9:0] hcnt = 10'd0;
reg [9:0] vcnt = 10'd0;

wire h_restart = hs_d && !hs_i;                  // trailing edge of the hsync of the core
wire h_wrap = h_restart || hcnt == H_TOTAL - 1;

always @(posedge clk) begin
	hs_d <= hs_i;
	if (vs_i) vs_seen <= 1'b1;
	if (h_wrap) begin
		hcnt <= 10'd0;
		vs_line <= vs_i;
		vs_seen <= vs_i;
		// a vsync seen in the line before and gone now: its trailing edge
		if ((vs_line || vs_seen) && !vs_i)
			vcnt <= 10'd0;
		else if (vcnt == V_TOTAL - 1)
			vcnt <= 10'd0;
		else
			vcnt <= vcnt + 10'd1;
	end
	else
		hcnt <= hcnt + 10'd1;
end

wire de_n = hcnt >= H_DE_X && hcnt < H_DE_X + H_DE_W && vcnt >= V_DE_Y && vcnt < V_DE_Y + V_DE_H;

always @(posedge clk) begin
	de <= de_n;
	hs <= hcnt >= H_SYNC_X;
	vs <= vcnt >= V_SYNC_Y;
	rgb <= de_n ? { r_i, r_i, g_i, g_i, b_i, b_i } : 24'd0;
end

endmodule
