`timescale 1ns / 1ps
// bbc_video_out: 864 x 625 with the syncs of the core (hsync every 864 clocks, a vsync every 624
// lines) and with none (free running); checks the line / frame lengths and the de window.
module tb_video_out;
reg clk = 0;
always #18.5 clk = ~clk;
reg hs_i = 0, vs_i = 0, run_syncs = 1;
wire [23:0] rgb; wire hs, vs, de;
bbc_video_out dut (.clk(clk), .r_i(4'hF), .g_i(4'h0), .b_i(4'h5), .hs_i(hs_i), .vs_i(vs_i),
	.rgb(rgb), .hs(hs), .vs(vs), .de(de));

integer x = 300, y = 0;   // the source starts at an odd place
always @(posedge clk) begin
	if (x == 863) begin x <= 0; y <= (y == 623) ? 0 : y + 1; end else x <= x + 1;
	hs_i <= run_syncs && x < 64;
	vs_i <= run_syncs && y >= 2 && y < 6;
end

integer hs_prev = 0, vs_prev = 0, hcnt = 0, line_len = 0, lines = 0, frame_len = 0, de_in_line = 0, de_lines = 0, de_w = 0, de_h = 0;
integer errors = 0, frames = 0;
always @(posedge clk) begin
	hcnt = hcnt + 1;
	if (de) de_in_line = de_in_line + 1;
	if (hs && !hs_prev) begin
		line_len = hcnt; hcnt = 0;
		lines = lines + 1;
		if (de_in_line) begin de_w = de_in_line; de_lines = de_lines + 1; end
		de_in_line = 0;
	end
	if (vs && !vs_prev) begin
		frame_len = lines; de_h = de_lines; lines = 0; de_lines = 0;
		frames = frames + 1;
		if (frames > 1) begin
			$display("frame %0d: line %0d, lines %0d, de %0d x %0d (syncs %0d)", frames, line_len, frame_len, de_w, de_h, run_syncs);
			if (line_len != 864 || de_w != 720 || de_h != 576 || (frame_len != 624 && frame_len != 625)) errors = errors + 1;
		end
	end
	hs_prev = hs; vs_prev = vs;
end

initial begin
	#(37 * 864 * 624 * 4);
	run_syncs = 0;
	#(37 * 864 * 625 * 3);
	if (errors) $display("FAIL %0d", errors); else $display("PASS");
	$finish;
end
endmodule
