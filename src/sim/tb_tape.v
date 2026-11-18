`timescale 1ns / 1ps
// bbc_tape: a small UEF (carrier, two data bytes) loaded through the LD_* bus of kg_mcu2 into the
// SDRAM (bbc_tape_sdram + sdram_model), then played with the motor on; checks the edges of cas_out:
// carrier 2 per 2400 Hz cycle, data 8N1 at 1200 baud ('0' one 1200 Hz cycle, '1' two 2400 Hz).
module tb_tape;
reg clk = 0;
always #10.4167 clk = ~clk;          // 48 MHz
reg reset = 1, lock = 0;
reg [1:0] ld_kind = 0; reg [7:0] ld_slot = 0; reg ld_start = 0, ld_active = 0, ld_wr = 0;
reg [31:0] ld_addr = 0; reg [7:0] ld_data = 0;
reg motor = 0;
wire cas_out, playing, error;
wire [12:0] A; wire [1:0] BA, DQM; wire [15:0] DQ; wire nRAS, nCAS, nWE;

bbc_tape #(.TAPE_SLOT(8'd2), .TICK_DIV(24)) dut (
	.clk(clk), .reset(reset), .lock(lock),
	.ld_kind(ld_kind), .ld_slot(ld_slot), .ld_start(ld_start), .ld_active(ld_active), .ld_wr(ld_wr),
	.ld_addr(ld_addr), .ld_data(ld_data),
	.motor(motor), .rewind(1'b0), .cas_out(cas_out), .playing(playing), .error(error),
	.SDRAM_A(A), .SDRAM_BA(BA), .SDRAM_DQ(DQ), .SDRAM_nRAS(nRAS), .SDRAM_nCAS(nCAS), .SDRAM_nWE(nWE),
	.SDRAM_DQM(DQM));
sdram_model mem (.clk(~clk), .a(A), .ba(BA), .dq(DQ), .nras(nRAS), .ncas(nCAS), .nwe(nWE), .dqm(DQM));

// UEF: "UEF File!" 0, version 0A 00; chunk 0110 len 2 carrier 40 cycles; chunk 0100 len 2: 55 AA
reg [7:0] uef [0:31];
integer n = 0;
task put(input [7:0] b); begin uef[n] = b; n = n + 1; end endtask
initial begin
	put("U"); put("E"); put("F"); put(" "); put("F"); put("i"); put("l"); put("e"); put("!"); put(8'h00);
	put(8'h0A); put(8'h00);
	put(8'h10); put(8'h01); put(8'h02); put(8'h00); put(8'h00); put(8'h00); put(8'd40); put(8'h00);
	put(8'h00); put(8'h01); put(8'h02); put(8'h00); put(8'h00); put(8'h00); put(8'h55); put(8'hAA);
end

integer edges = 0, k;
reg cas_d = 0;
always @(posedge clk) begin
	cas_d <= cas_out;
	if (cas_out != cas_d) edges = edges + 1;
end

initial begin
	#200 lock = 1; reset = 0;
	wait (dut.sdram.init);
	@(posedge clk) begin ld_kind <= 2; ld_slot <= 2; ld_start <= 1; ld_active <= 1; end
	@(posedge clk) ld_start <= 0;
	for (k = 0; k < n; k = k + 1) begin
		@(posedge clk) begin ld_wr <= 1; ld_addr <= k; ld_data <= uef[k]; end
		@(posedge clk) ld_wr <= 0;
		repeat (10) @(posedge clk);          // a byte each 12 clocks, as the link at 32 MHz
	end
	@(posedge clk) ld_active <= 0;
	repeat (200) @(posedge clk);
	if (dut.size != n) begin $display("FAIL size %0d, not %0d", dut.size, n); $finish; end
	for (k = 0; k < n; k = k + 1)
		if (mem.mem[k >> 1][(k & 1) * 8 +: 8] !== uef[k]) begin $display("FAIL byte %0d", k); $finish; end
	motor = 1;
	wait (playing);
	wait (!playing);
	repeat (2000) @(posedge clk);
	// carrier 40 x 2400 Hz = 80 edges; bytes 55 AA, 8N1 LSB first: start 0, data, stop 1
	// 0x55 = 1,0,1,0,1,0,1,0 -> four 1s, four 0s; 0xAA the same: per byte 0s 1+4 = 5 (2 edges each),
	// 1s 4+1 = 5 (4 edges each) = 30 edges a byte
	$display("edges %0d (expected 80 + 60 = 140), error %0d", edges, error);
	if (edges == 140 && !error) $display("PASS"); else $display("FAIL");
	$finish;
end
initial begin #50_000_000 $display("FAIL timeout, edges %0d", edges); $finish; end
endmodule
