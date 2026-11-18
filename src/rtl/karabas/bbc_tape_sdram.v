`timescale 1ns / 1ps
`default_nettype wire
/*
 bbc_tape_sdram.v

 One byte port on the 32 MB SDRAM of the Karabas boards (16M x 16: 4 banks, 8192 rows, 512 columns)
 for the tape image: a few hundred kilobytes written once by the loader, then read a byte at a time
 by the UEF player (about 150 bytes a second). Made from bk_sdram.v of core-bk (the same chip, the
 same pad scheme), cut down to one port and single accesses.

 One clock, 48 MHz (20.8 ns). CAS latency 2, burst length 1, every access ACTIVE, NOP, READ / WRITE
 with auto precharge:
   read   the word lands in dq_in 5 clocks after its READ (the pipe of bk_sdram), ack with rdata
   write  ack one clock after the WRITE; the next ACTIVE 4 clocks after it (tWR + tRP)
 tRCD 2 clocks = 42 ns, tRC >= 6 clocks = 125 ns, tRFC 6 = 125 ns.

 The pads (as bk_sdram): the chip gets the inverted clock (an ODDR2 in the top), commands and write
 data are taken half a clock after our edge; read data is taken on the falling edge E + 2.5 after the
 READ at E (at 48 MHz: on the pins from about E + 1.5 + tAC 6 ns to E + 2.5 + tOH 2.5 ns plus the pad
 delays, the falling edge near its middle) and handed over at E + 3.

 The byte address a[24:0]: the word a[24:1] = { bank 2, row 13, column 9 }, the lane a[0] (0 = DQ[7:0]).

 Refresh: 8192 rows in 64 ms = one per 7.8 us = 375 clocks: due every 360, taken between accesses,
 forced at two due.
*/
module bbc_tape_sdram (
	input wire clk,
	input wire lock,            // the PLL has locked
	output wire init,           // the memory is initialised

	input wire req,             // held until ack
	input wire we,
	input wire [24:0] adr,
	input wire [7:0] wdata,
	output reg ack = 1'b0,      // one clock, with rdata on a read
	output reg [7:0] rdata = 8'd0,

	// the chip (~CS is tied on the boards)
	output reg [12:0] SDRAM_A = 13'd0,
	output reg [1:0] SDRAM_BA = 2'd0,
	inout wire [15:0] SDRAM_DQ,
	output reg SDRAM_nRAS = 1'b1,
	output reg SDRAM_nCAS = 1'b1,
	output reg SDRAM_nWE = 1'b1,
	output reg [1:0] SDRAM_DQM = 2'b11
);

localparam [2:0] CMD_NOP = 3'b111, CMD_ACTIVE = 3'b011, CMD_READ = 3'b101, CMD_WRITE = 3'b100,
                 CMD_PRECHARGE = 3'b010, CMD_REFRESH = 3'b001, CMD_MODE = 3'b000;

// burst length 1, sequential, CAS latency 2
localparam [12:0] MODE = 13'b000_0_00_010_0_000;

// the data lines: a flip-flop each, so that they all go into the IOBs
(* EQUIVALENT_REGISTER_REMOVAL = "no" *) reg [15:0] dq_t = 16'hFFFF;
reg [15:0] dq_out = 16'd0;
genvar gi;
generate for (gi = 0; gi < 16; gi = gi + 1) begin : dq_pad
	assign SDRAM_DQ[gi] = dq_t[gi] ? 1'bz : dq_out[gi];
end endgenerate

reg [15:0] dq_neg = 16'd0, dq_in = 16'd0;
always @(negedge clk) dq_neg <= SDRAM_DQ;
always @(posedge clk) dq_in <= dq_neg;

// power up: 65536 clocks of NOP after the lock, then the JEDEC steps
reg [15:0] settle = 16'd0;
reg [6:0] istep = 7'd127;
reg started = 1'b0;
wire running = started && (istep == 7'd0);
assign init = running;

reg [8:0] ref_cnt = 9'd0;
reg [2:0] ref_due = 3'd0;

localparam [1:0] S_IDLE = 2'd0, S_ACC = 2'd1, S_REF = 2'd2;
reg [1:0] st = S_IDLE;
reg [3:0] t = 4'd0;
reg act_we = 1'b0;
reg act_lane = 1'b0;
reg [8:0] act_col = 9'd0;
reg [7:0] act_data = 8'd0;

// the read in flight: { valid, lane } five clocks behind its READ
reg [1:0] pipe0 = 2'd0, pipe1 = 2'd0, pipe2 = 2'd0, pipe3 = 2'd0;

wire ref_force = ref_due >= 3'd2;

always @(posedge clk) begin
	{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
	SDRAM_DQM <= 2'b11;
	dq_t <= 16'hFFFF;
	ack <= 1'b0;

	pipe0 <= 2'd0;
	pipe1 <= pipe0; pipe2 <= pipe1; pipe3 <= pipe2;
	if (pipe3[1]) begin
		rdata <= pipe3[0] ? dq_in[15:8] : dq_in[7:0];
		ack <= 1'b1;
	end

	if (!lock) begin
		settle <= 16'd0; istep <= 7'd127; started <= 1'b0;
		ref_due <= 3'd0; ref_cnt <= 9'd0; st <= S_IDLE; t <= 4'd0;
	end
	else if (!started) begin
		if (&settle) started <= 1'b1;
		else settle <= settle + 16'd1;
	end
	else if (istep != 7'd0) begin
		// the JEDEC steps, eight clocks apart
		istep <= istep - 7'd1;
		case (istep)
			7'd64: begin {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE; SDRAM_A <= 13'h0400; end
			7'd56, 7'd48, 7'd40, 7'd32: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_REFRESH;
			7'd16: begin {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_MODE; SDRAM_A <= MODE; SDRAM_BA <= 2'd0; end
			default: ;
		endcase
	end
	else begin
		if (ref_cnt == 9'd359) begin
			ref_cnt <= 9'd0;
			if (ref_due != 3'd7) ref_due <= ref_due + 3'd1;
		end
		else
			ref_cnt <= ref_cnt + 9'd1;

		case (st)
		S_IDLE: begin
			t <= 4'd0;
			if (ref_force || (ref_due != 3'd0 && !req)) begin
				{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_REFRESH;
				ref_due <= (ref_cnt == 9'd359) ? ref_due : ref_due - 3'd1;
				st <= S_REF;
			end
			else if (req) begin
				{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACTIVE;
				SDRAM_BA <= adr[24:23];
				SDRAM_A <= adr[22:10];
				act_col <= adr[9:1];
				act_lane <= adr[0];
				act_we <= we;
				act_data <= wdata;
				st <= S_ACC;
			end
		end
		S_REF: begin
			t <= t + 4'd1;
			if (t == 4'd5) st <= S_IDLE;
		end
		S_ACC: begin
			t <= t + 4'd1;
			if (t == 4'd1) begin
				// t = 1: two clocks after the ACTIVE (tRCD); A10 = auto precharge
				SDRAM_A <= { 2'b00, 1'b1, 1'b0, act_col };
				if (act_we) begin
					{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_WRITE;
					dq_out <= { act_data, act_data };
					dq_t <= 16'h0000;
					SDRAM_DQM <= act_lane ? 2'b01 : 2'b10;
					ack <= 1'b1;
				end
				else begin
					{SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_READ;
					SDRAM_DQM <= 2'b00;
					pipe0 <= { 1'b1, act_lane };
				end
			end
			// the next ACTIVE no sooner than tRC; a read waits for its word (ack at t = 6)
			if (t == (act_we ? 4'd5 : 4'd6)) st <= S_IDLE;
		end
		default: st <= S_IDLE;
		endcase
	end
end

endmodule
