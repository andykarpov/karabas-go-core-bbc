`timescale 1ns / 1ps
`default_nettype wire
/*
 bbc_tape.v

 The cassette: a UEF image from the FL item Tape (link v2 LOAD kind 2, slot TAPE_SLOT) in the SDRAM
 (bbc_tape_sdram), played by tape_player of Welsh71/BBCMicro.Alternate_MiSTer (UEF chunks 0100 /
 0102 / 0104 / 0110 / 0111 / 0112 / 0116 / 0117, the BBC timing 16 MHz / 13 / 64) as the squared
 tape signal for the Serial ULA of the core (cas_in), while the cassette motor is on.

 - a load: LD_START of the slot = size 0 (the player stops, rewinds), the bytes go through a fifo
   of 16 into the SDRAM at their LD_ADDR (a write takes 6 clocks, the link gives a byte at most every
   8 MCU clocks = 12 clk at 32 MHz), LD_END = size = the highest address + 1;
 - rewind: a load, or the OSD trigger;
 - gzip images (1F 8B) are recognised by the player and not played (error); unpack them first.
*/
module bbc_tape #(
	parameter [7:0] TAPE_SLOT = 8'd2,
	parameter integer TICK_DIV = 2496    // 48 MHz / (16 MHz / 13 / 64)
) (
	input wire clk,
	input wire reset,
	input wire lock,

	// kg_mcu2 LD_*
	input wire [1:0] ld_kind,
	input wire [7:0] ld_slot,
	input wire ld_start,
	input wire ld_active,
	input wire ld_wr,
	input wire [31:0] ld_addr,
	input wire [7:0] ld_data,

	input wire motor,
	input wire rewind,
	output wire cas_out,
	output wire playing,
	output wire error,

	// the SDRAM
	output wire [12:0] SDRAM_A,
	output wire [1:0] SDRAM_BA,
	inout wire [15:0] SDRAM_DQ,
	output wire SDRAM_nRAS,
	output wire SDRAM_nCAS,
	output wire SDRAM_nWE,
	output wire [1:0] SDRAM_DQM
);

wire mine = ld_kind == 2'd2 && ld_slot == TAPE_SLOT;

// the SDRAM port state (below)
localparam [1:0] A_IDLE = 2'd0, A_FETCH = 2'd1, A_WAIT = 2'd2;
reg [1:0] ast = A_IDLE;

// ---------------------------------------------------------------- the load

reg loading = 1'b0;
reg [24:0] size = 25'd0, top = 25'd0;
always @(posedge clk) begin
	if (reset) begin
		loading <= 1'b0;
		size <= 25'd0;
		top <= 25'd0;
	end
	else begin
		if (ld_start && mine) begin
			loading <= 1'b1;
			size <= 25'd0;
			top <= 25'd0;
		end
		else if (loading && !ld_active && w_empty && ast == A_IDLE) begin
			loading <= 1'b0;
			size <= top;
		end
		if (loading && ld_wr && ld_addr[24:0] + 25'd1 > top)
			top <= ld_addr[24:0] + 25'd1;
	end
end

wire w_empty, w_full;
wire [32:0] w_dout;
reg w_rd = 1'b0;
kg_fifo #(.DW(33), .AW(4)) wfifo (
	.clk(clk),
	.reset(reset),
	.wr(loading && ld_wr),
	.din({ ld_addr[24:0], ld_data }),
	.full(w_full),
	.rd(w_rd),
	.dout(w_dout),
	.empty(w_empty),
	.count()
);

// ---------------------------------------------------------------- the player

wire p_rd;
wire [24:0] p_addr;
reg p_valid = 1'b0;
wire [7:0] rdata;

tape_player #(.TICK_DIV(TICK_DIV)) player (
	.clk(clk),
	.rst(reset),
	.motor(motor),
	.rewind(rewind || loading),
	.size(size),
	.mem_rd(p_rd),
	.mem_addr(p_addr),
	.mem_data(rdata),
	.mem_valid(p_valid),
	.cas_out(cas_out),
	.playing(playing),
	.error(error),
	.fmt(),
	.position()
);

// ---------------------------------------------------------------- the SDRAM port

// IDLE: the fifo first (writes of a load), else a read the player asked for (p_pend, its address
// taken at its mem_rd strobe); FETCH: the fifo word is out (kg_fifo dout registered); WAIT: until ack
reg req = 1'b0, req_we = 1'b0;
reg [24:0] req_adr = 25'd0;
reg [7:0] req_wdata = 8'd0;
reg p_pend = 1'b0;
reg [24:0] p_addr_l = 25'd0;
wire ack;

always @(posedge clk) begin
	p_valid <= 1'b0;
	w_rd <= 1'b0;
	if (p_rd) begin
		p_pend <= 1'b1;
		p_addr_l <= p_addr;
	end
	if (reset) begin
		ast <= A_IDLE; req <= 1'b0; p_pend <= 1'b0;
	end
	else case (ast)
	A_IDLE:
		if (!w_empty && !w_rd) begin
			w_rd <= 1'b1;
			req_we <= 1'b1;
			ast <= A_FETCH;
		end
		else if (p_pend && !p_rd) begin
			req <= 1'b1;
			req_we <= 1'b0;
			req_adr <= p_addr_l;
			ast <= A_WAIT;
		end
	A_FETCH:
		if (!w_rd) begin
			req <= 1'b1;
			req_adr <= w_dout[32:8];
			req_wdata <= w_dout[7:0];
			ast <= A_WAIT;
		end
	A_WAIT:
		if (ack) begin
			req <= 1'b0;
			if (!req_we) begin
				p_valid <= 1'b1;
				p_pend <= 1'b0;
			end
			ast <= A_IDLE;
		end
	default: ast <= A_IDLE;
	endcase
end

wire sd_init;
bbc_tape_sdram sdram (
	.clk(clk),
	.lock(lock),
	.init(sd_init),
	.req(req),
	.we(req_we),
	.adr(req_adr),
	.wdata(req_wdata),
	.ack(ack),
	.rdata(rdata),
	.SDRAM_A(SDRAM_A),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_DQM(SDRAM_DQM)
);

endmodule
