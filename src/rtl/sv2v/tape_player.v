module tape_player (
	clk,
	rst,
	motor,
	rewind,
	size,
	mem_rd,
	mem_addr,
	mem_data,
	mem_valid,
	cas_out,
	playing,
	error,
	fmt,
	position
);
	parameter integer TICK_DIV = 4992;
	input wire clk;
	input wire rst;
	input wire motor;
	input wire rewind;
	input wire [24:0] size;
	output reg mem_rd;
	output reg [24:0] mem_addr;
	input wire [7:0] mem_data;
	input wire mem_valid;
	output wire cas_out;
	output wire playing;
	output wire error;
	output reg [1:0] fmt;
	output wire [24:0] position;
	reg [1:0] motor_s;
	always @(posedge clk) motor_s <= {motor_s[0], motor};
	wire mot = motor_s[1];
	reg [24:0] pos;
	reg have;
	reg pend;
	reg [7:0] cur;
	reg take;
	reg seek;
	reg [24:0] seek_pos;
	reg seek_req;
	reg [24:0] seek_tgt;
	wire eof = pos >= size;
	assign position = pos;
	always @(posedge clk) begin
		mem_rd <= 1'b0;
		if (rst || rewind) begin
			pos <= 25'd0;
			have <= 1'b0;
			pend <= 1'b0;
			seek_req <= 1'b0;
		end
		else begin
			if (mem_valid && pend) begin
				pend <= 1'b0;
				if (!seek && !seek_req) begin
					cur <= mem_data;
					have <= 1'b1;
				end
			end
			if (seek) begin
				seek_req <= 1'b1;
				seek_tgt <= seek_pos;
				have <= 1'b0;
			end
			else if (seek_req) begin
				if (!pend || mem_valid) begin
					pos <= seek_tgt;
					have <= 1'b0;
					seek_req <= 1'b0;
				end
			end
			else if (take) begin
				pos <= pos + 25'd1;
				have <= 1'b0;
			end
			else if ((!have && !pend) && !eof) begin
				mem_rd <= 1'b1;
				mem_addr <= pos;
				pend <= 1'b1;
			end
		end
	end
	localparam SYM_H = 2'd0;
	localparam SYM_L = 2'd1;
	localparam SYM_S = 2'd2;
	reg [12:0] tdiv;
	reg tick;
	reg e_busy;
	reg [1:0] e_typ;
	reg [23:0] e_left;
	reg [3:0] e_ph;
	reg sym_valid;
	reg [1:0] sym_type;
	reg [23:0] sym_count;
	wire sym_take;
	localparam P_IDLE = 5'd0;
	localparam P_HDR = 5'd1;
	localparam P_CH = 5'd2;
	localparam P_DISP = 5'd3;
	localparam P_SKIP = 5'd4;
	localparam P_DATA = 5'd5;
	localparam P_FRAME = 5'd6;
	localparam P_RAW = 5'd7;
	localparam P_RAWB = 5'd8;
	localparam P_BS = 5'd9;
	localparam P_BSB = 5'd10;
	localparam P_RDN = 5'd11;
	localparam P_EMIT = 5'd12;
	localparam P_DUMMY = 5'd13;
	localparam P_END = 5'd14;
	localparam P_ERR = 5'd15;
	localparam P_FLOAT = 5'd16;
	localparam P_FMT = 5'd17;
	reg [4:0] ps;
	reg [4:0] ret;
	reg [3:0] hidx;
	reg gz0;
	reg [15:0] ch_id;
	reg [24:0] ch_end;
	reg [31:0] acc;
	reg [2:0] acc_n;
	reg [2:0] acc_i;
	reg [2:0] loops;
	reg [3:0] f_bits;
	reg [1:0] f_par;
	reg [1:0] f_stop;
	reg [11:0] fr;
	reg [3:0] fr_n;
	reg [4:0] fr_ret;
	reg [27:0] raw_left;
	reg [3:0] bit_i;
	reg [1:0] step;
	reg [15:0] n2;
	function [7:0] magic;
		input [3:0] i;
		case (i)
			4'd0: magic = "U";
			4'd1: magic = "E";
			4'd2: magic = "F";
			4'd3: magic = " ";
			4'd4: magic = "F";
			4'd5: magic = "i";
			4'd6: magic = "l";
			4'd7: magic = "e";
			4'd8: magic = "!";
			default: magic = 8'h00;
		endcase
	endfunction
	function [11:0] mkframe;
		input [7:0] b;
		input [3:0] nb;
		input [1:0] par;
		input [1:0] nstop;
		reg [11:0] f;
		reg p;
		integer k;
		begin
			f = 12'hfff;
			f[0] = 1'b0;
			p = 1'b0;
			for (k = 0; k < 8; k = k + 1)
				if (k < nb) begin
					f[1 + k] = b[k];
					p = p ^ b[k];
				end
			if (par != 2'd0)
				f[1 + nb] = (par == 2'd2 ? ~p : p);
			mkframe = f;
		end
	endfunction
	function [3:0] frlen;
		input [3:0] nb;
		input [1:0] par;
		input [1:0] nstop;
		frlen = ((4'd1 + nb) + (par != 2'd0 ? 4'd1 : 4'd0)) + {2'b00, nstop};
	endfunction
	wire [23:0] fl_mant = {1'b1, acc[22:0]};
	wire [7:0] fl_exp = acc[30:23];
	reg [35:0] fl_prod;
	reg [7:0] fl_exp_r;
	reg fl_zero;
	reg [23:0] fl_units;
	always @(posedge clk) begin
		fl_prod <= fl_mant * 12'd2400;
		fl_exp_r <= fl_exp;
		fl_zero <= (fl_exp == 8'd0) || acc[31];
		if (fl_zero || (fl_exp_r < 8'd114))
			fl_units <= 24'd0;
		else if (fl_exp_r >= 8'd150)
			fl_units <= (fl_exp_r > 8'd160 ? 24'hffffff : fl_prod[23:0] << (fl_exp_r - 8'd150));
		else
			fl_units <= fl_prod >> (8'd150 - fl_exp_r);
	end
	wire bit_cur = cur[3'd7 - bit_i[2:0]];
	wire ps_next_ch = have && (hidx == 4'd11);
	wire [7:0] stop_mag = (acc[23] ? 8'd0 - acc[23:16] : acc[23:16]);
	always @(posedge clk) begin
		take <= 1'b0;
		seek <= 1'b0;
		if (sym_take)
			sym_valid <= 1'b0;
		if (rst || rewind) begin
			ps <= P_IDLE;
			sym_valid <= 1'b0;
			loops <= 3'd1;
			hidx <= 4'd0;
			fmt <= 2'd0;
		end
		else if ((!take && !seek) && !seek_req) begin
			if (ps == P_HDR) begin
				if (ps_next_ch)
					fmt <= 2'd1;
			end
			if ((ps == P_BS) && (fmt == 2'd0))
				fmt <= 2'd2;
			if (ps == P_ERR)
				fmt <= 2'd3;
			case (ps)
				P_IDLE:
					if (size != 25'd0) begin
						ps <= P_HDR;
						hidx <= 4'd0;
					end
				P_HDR:
					if (eof)
						ps <= P_END;
					else if (have) begin
						if (hidx == 4'd0) begin
							gz0 <= cur == 8'h1f;
							if ((cur == 8'h1f) || (cur == "U")) begin
								take <= 1'b1;
								hidx <= 4'd1;
							end
							else begin
								seek_pos <= 25'd0;
								seek <= 1'b1;
								ps <= P_BS;
							end
						end
						else if ((hidx == 4'd1) && gz0) begin
							if (cur == 8'h8b)
								ps <= P_ERR;
							else begin
								seek_pos <= 25'd0;
								seek <= 1'b1;
								ps <= P_BS;
							end
						end
						else if ((hidx < 4'd10) && (cur != magic(hidx))) begin
							seek_pos <= 25'd0;
							seek <= 1'b1;
							ps <= P_BS;
						end
						else begin
							take <= 1'b1;
							hidx <= hidx + 4'd1;
							if (hidx == 4'd11)
								ps <= P_CH;
						end
					end
				P_CH:
					if (eof)
						ps <= P_END;
					else begin
						acc_n <= 3'd6;
						acc_i <= 3'd0;
						acc <= 32'd0;
						ret <= P_DISP;
						ch_id <= 16'd0;
						ps <= P_RDN;
					end
				P_RDN:
					if (acc_i == acc_n)
						ps <= ret;
					else if (eof)
						ps <= P_END;
					else if (have) begin
						take <= 1'b1;
						if (((ret == P_DISP) && (acc_n == 3'd6)) && (acc_i < 3'd2))
							ch_id[acc_i[0] * 8+:8] <= cur;
						else if ((ret == P_DISP) && (acc_n == 3'd6))
							acc[(acc_i - 3'd2) * 8+:8] <= cur;
						else
							acc[acc_i * 8+:8] <= cur;
						acc_i <= acc_i + 3'd1;
					end
				P_DISP: begin
					ch_end <= pos + acc[24:0];
					step <= 2'd0;
					case (ch_id)
						16'h0100: begin
							f_bits <= 4'd8;
							f_par <= 2'd0;
							f_stop <= 2'd1;
							ps <= P_DATA;
						end
						16'h0104: begin
							acc_n <= 3'd3;
							acc_i <= 3'd0;
							acc <= 32'd0;
							ret <= P_FMT;
							ps <= P_RDN;
						end
						16'h0102: begin
							raw_left <= {acc[24:0], 3'b000};
							acc_n <= 3'd1;
							acc_i <= 3'd0;
							ret <= P_RAW;
							ps <= P_RDN;
						end
						16'h0110, 16'h0112, 16'h0117, 16'h0111: begin
							acc_n <= (ch_id == 16'h0111 ? 3'd4 : 3'd2);
							acc_i <= 3'd0;
							acc <= 32'd0;
							ret <= P_EMIT;
							ps <= P_RDN;
						end
						16'h0116: begin
							acc_n <= 3'd4;
							acc_i <= 3'd0;
							acc <= 32'd0;
							ret <= P_FLOAT;
							ps <= P_RDN;
						end
						default: ps <= P_SKIP;
					endcase
				end
				P_SKIP: begin
					seek_pos <= ch_end;
					seek <= 1'b1;
					ps <= P_CH;
				end
				P_FMT: begin
					f_bits <= ((acc[7:0] >= 8'd1) && (acc[7:0] <= 8'd8) ? acc[3:0] : 4'd8);
					f_par <= (acc[15:8] == "E" ? 2'd1 : (acc[15:8] == "O" ? 2'd2 : 2'd0));
					f_stop <= (stop_mag > 8'd2 ? 2'd2 : stop_mag[1:0]);
					ps <= P_DATA;
				end
				P_DATA:
					if ((pos >= ch_end) || eof)
						ps <= P_SKIP;
					else if (have) begin
						fr <= mkframe(cur, f_bits, f_par, f_stop);
						fr_n <= frlen(f_bits, f_par, f_stop);
						fr_ret <= P_DATA;
						take <= 1'b1;
						ps <= P_FRAME;
					end
				P_FRAME:
					if (fr_n == 4'd0)
						ps <= fr_ret;
					else if (!sym_valid) begin
						sym_valid <= 1'b1;
						sym_type <= (fr[0] ? SYM_H : SYM_L);
						sym_count <= (fr[0] ? {20'd0, loops, 1'b0} : {21'd0, loops});
						fr <= {1'b1, fr[11:1]};
						fr_n <= fr_n - 4'd1;
					end
				P_RAW: begin
					raw_left <= (raw_left - 28'd8) - {20'd0, acc[7:0]};
					bit_i <= 4'd8;
					ps <= P_RAWB;
				end
				P_RAWB:
					if (raw_left == 28'd0)
						ps <= P_SKIP;
					else if (bit_i == 4'd8) begin
						if ((pos >= ch_end) || eof)
							ps <= P_SKIP;
						else if (have) begin
							fr <= {4'hf, cur};
							bit_i <= 4'd0;
							take <= 1'b1;
						end
					end
					else if (!sym_valid) begin
						sym_valid <= 1'b1;
						sym_type <= (fr[0] ? SYM_H : SYM_L);
						sym_count <= (fr[0] ? {20'd0, loops, 1'b0} : {21'd0, loops});
						fr <= {1'b1, fr[11:1]};
						bit_i <= bit_i + 4'd1;
						raw_left <= raw_left - 28'd1;
					end
				P_EMIT:
					case (ch_id)
						16'h0110:
							if (!sym_valid) begin
								if (acc[15:0] != 16'd0) begin
									sym_valid <= 1'b1;
									sym_type <= SYM_H;
									sym_count <= {8'd0, acc[15:0]};
								end
								ps <= P_SKIP;
							end
						16'h0112:
							if (!sym_valid) begin
								if (acc[15:0] != 16'd0) begin
									sym_valid <= 1'b1;
									sym_type <= SYM_S;
									sym_count <= {8'd0, acc[15:0]};
								end
								ps <= P_SKIP;
							end
						16'h0117: begin
							loops <= (acc[15:0] == 16'd300 ? 3'd4 : 3'd1);
							ps <= P_SKIP;
						end
						default:
							if (!sym_valid) begin
								n2 <= acc[31:16];
								if (acc[15:0] != 16'd0) begin
									sym_valid <= 1'b1;
									sym_type <= SYM_H;
									sym_count <= {8'd0, acc[15:0]};
								end
								fr <= mkframe(8'haa, 4'd8, 2'd0, 2'd1);
								fr_n <= 4'd10;
								fr_ret <= P_DUMMY;
								ps <= P_FRAME;
							end
					endcase
				P_DUMMY:
					if (!sym_valid) begin
						if (n2 != 16'd0) begin
							sym_valid <= 1'b1;
							sym_type <= SYM_H;
							sym_count <= {8'd0, n2};
						end
						ps <= P_SKIP;
					end
				P_FLOAT:
					if (step != 2'd3)
						step <= step + 2'd1;
					else if (!sym_valid) begin
						if (fl_units != 24'd0) begin
							sym_valid <= 1'b1;
							sym_type <= SYM_S;
							sym_count <= fl_units;
						end
						ps <= P_SKIP;
					end
				P_BS:
					if (eof)
						ps <= P_END;
					else if (have) begin
						bit_i <= 4'd0;
						ps <= P_BSB;
					end
				P_BSB:
					if (bit_i == 4'd8) begin
						take <= 1'b1;
						ps <= P_BS;
					end
					else if (!sym_valid) begin
						sym_valid <= 1'b1;
						sym_type <= (bit_cur ? SYM_H : SYM_L);
						sym_count <= (bit_cur ? 24'd2 : 24'd1);
						bit_i <= bit_i + 4'd1;
					end
				P_END, P_ERR:
					;
				default: ps <= P_END;
			endcase
		end
	end
	assign error = ps == P_ERR;
	assign playing = ((mot && (ps != P_IDLE)) && (ps != P_ERR)) && !((ps == P_END) && !e_busy);
	wire [4:0] e_len = (e_typ == SYM_L ? 5'd16 : 5'd8);
	reg cas_r;
	assign cas_out = cas_r & mot;
	assign sym_take = sym_valid && !e_busy;
	always @(posedge clk) begin
		tick <= 1'b0;
		if (rst || rewind) begin
			tdiv <= 13'd0;
			e_busy <= 1'b0;
			cas_r <= 1'b0;
		end
		else begin
			if (mot) begin
				if (tdiv == (TICK_DIV - 1)) begin
					tdiv <= 13'd0;
					tick <= 1'b1;
				end
				else
					tdiv <= tdiv + 13'd1;
			end
			if (sym_take) begin
				if (sym_count != 24'd0) begin
					e_busy <= 1'b1;
					e_typ <= sym_type;
					e_left <= sym_count;
					e_ph <= 4'd0;
					cas_r <= sym_type != SYM_S;
				end
			end
			else if (tick && e_busy) begin
				if (({1'b0, e_ph} + 5'd1) == e_len) begin
					e_ph <= 4'd0;
					if (e_left == 24'd1) begin
						e_busy <= 1'b0;
						cas_r <= 1'b0;
					end
					else begin
						e_left <= e_left - 24'd1;
						cas_r <= e_typ != SYM_S;
					end
				end
				else begin
					e_ph <= e_ph + 4'd1;
					cas_r <= (e_typ != SYM_S) && (({1'b0, e_ph} + 5'd1) < (e_len >> 1));
				end
			end
		end
	end
endmodule
