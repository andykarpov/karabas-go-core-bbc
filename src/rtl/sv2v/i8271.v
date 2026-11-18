module i8271 (
	clk,
	ce4m,
	reset,
	cpu_ce,
	cpu_sel,
	cpu_rw,
	cpu_addr,
	cpu_din,
	cpu_dout,
	nmi,
	img_mounted,
	img_size,
	ext_drive,
	ext_lba,
	ext_rd,
	ext_wr,
	ext_busy,
	buf_addr,
	buf_din,
	buf_we,
	buf_q,
	drive_led,
	seek_tog,
	seek_n,
	disk_info
);
	input clk;
	input ce4m;
	input reset;
	input cpu_ce;
	input cpu_sel;
	input cpu_rw;
	input [2:0] cpu_addr;
	input [7:0] cpu_din;
	output reg [7:0] cpu_dout;
	output wire nmi;
	input [1:0] img_mounted;
	input [31:0] img_size;
	output reg ext_drive;
	output reg [31:0] ext_lba;
	output reg ext_rd;
	output reg ext_wr;
	input ext_busy;
	output reg [8:0] buf_addr;
	output reg [7:0] buf_din;
	output reg buf_we;
	input [7:0] buf_q;
	output wire drive_led;
	output reg seek_tog;
	output reg [6:0] seek_n;
	output wire [23:0] disk_info;
	localparam ST_BUSY = 7;
	localparam ST_CMDF = 6;
	localparam ST_PARF = 5;
	localparam ST_RESF = 4;
	localparam ST_INT = 3;
	localparam ST_NDMA = 2;
	localparam R_OK = 8'h00;
	localparam R_NOT_FOUND = 8'h18;
	localparam BYTE_TICKS = 9'd255;
	localparam CRC_TICKS = 10'd511;
	localparam MS_TICKS = 12'd3999;
	localparam REV_TICKS = 20'd799999;
	localparam IDX_TICKS = 20'd16000;
	localparam SECT_TICKS = 20'd80000;
	reg [1:0] present = 2'b00;
	reg [1:0] dsided = 2'b00;
	reg [1:0] img_mounted_d;
	always @(posedge clk) begin
		img_mounted_d <= img_mounted;
		if (img_mounted[0] & ~img_mounted_d[0]) begin
			present[0] <= |img_size;
			dsided[0] <= img_size > 32'd409500;
		end
		if (img_mounted[1] & ~img_mounted_d[1]) begin
			present[1] <= |img_size;
			dsided[1] <= img_size > 32'd409500;
		end
	end
	reg [7:0] status;
	reg [7:0] result;
	reg [7:0] data_out;
	reg [7:0] data_in;
	reg [5:0] cmd;
	reg [7:0] par0;
	reg [7:0] par1;
	reg [7:0] par2;
	reg [7:0] par3;
	reg [7:0] par4;
	reg [2:0] pcnt;
	reg [2:0] preq;
	reg [7:0] drvout;
	reg [7:0] curtrk0;
	reg [7:0] curtrk1;
	reg [6:0] phys0;
	reg [6:0] phys1;
	reg [7:0] step_ms;
	reg [7:0] settle_ms;
	reg [7:0] load_ms;
	reg [3:0] unload_revs;
	wire drv = drvout[7];
	wire side = drvout[5];
	wire [6:0] phys = (drv ? phys1 : phys0);
	wire [7:0] curtrk = (drv ? curtrk1 : curtrk0);
	wire [6:0] new_phys = (par0 > 8'd81 ? 7'd81 : par0[6:0]);
	assign nmi = status[ST_INT];
	always @(*)
		if (cpu_addr[2])
			cpu_dout = data_out;
		else if (cpu_addr[1:0] == 2'd0)
			cpu_dout = status;
		else if (cpu_addr[1:0] == 2'd1)
			cpu_dout = result;
		else
			cpu_dout = 8'h00;
	reg [19:0] rev;
	reg motor;
	reg [27:0] unload_cnt;
	wire index = motor && (rev < IDX_TICKS);
	wire [3:0] rot_sector = (rev < (SECT_TICKS * 1) ? 4'd0 : (rev < (SECT_TICKS * 2) ? 4'd1 : (rev < (SECT_TICKS * 3) ? 4'd2 : (rev < (SECT_TICKS * 4) ? 4'd3 : (rev < (SECT_TICKS * 5) ? 4'd4 : (rev < (SECT_TICKS * 6) ? 4'd5 : (rev < (SECT_TICKS * 7) ? 4'd6 : (rev < (SECT_TICKS * 8) ? 4'd7 : (rev < (SECT_TICKS * 9) ? 4'd8 : 4'd9)))))))));
	assign drive_led = motor;
	reg [1:0] busy_s;
	always @(posedge clk) busy_s <= {busy_s[0], ext_busy};
	wire sd_busy = busy_s[1];
	localparam S_IDLE = 5'd0;
	localparam S_DELAY = 5'd1;
	localparam S_SECTOR = 5'd2;
	localparam S_SD_WAIT = 5'd3;
	localparam S_RD_FETCH = 5'd4;
	localparam S_RD_FETCH2 = 5'd5;
	localparam S_RD_OFFER = 5'd6;
	localparam S_RD_TAKEN = 5'd7;
	localparam S_WR_ASK = 5'd8;
	localparam S_WR_WAIT = 5'd9;
	localparam S_WR_FLUSH = 5'd10;
	localparam S_NEXT = 5'd11;
	localparam S_DONE = 5'd12;
	localparam S_ID_OFFER = 5'd13;
	localparam S_ID_TAKEN = 5'd14;
	localparam S_VERIFY = 5'd15;
	localparam S_FMT_ASK = 5'd16;
	localparam S_FMT_WAIT = 5'd17;
	localparam S_FMT_FILL = 5'd18;
	localparam S_SD_START = 5'd19;
	localparam S_FMT_PUT = 5'd20;
	localparam S_FMT_NEXT = 5'd21;
	localparam S_FINISH = 5'd22;
	localparam OP_READ = 3'd0;
	localparam OP_WRITE = 3'd1;
	localparam OP_VERIFY = 3'd2;
	localparam OP_READID = 3'd3;
	localparam OP_FORMAT = 3'd4;
	localparam OP_SEEK = 3'd5;
	reg [4:0] state;
	reg [4:0] next_state;
	reg [4:0] sd_next;
	reg [2:0] op;
	reg [15:0] delay_ms;
	reg [11:0] ms_sub;
	reg [8:0] byte_tick;
	reg [8:0] nbytes;
	reg [8:0] bcnt;
	reg [7:0] sector;
	reg [4:0] nleft;
	reg [1:0] idb;
	reg [7:0] fmt_id;
	reg [3:0] id_sector;
	reg half;
	reg sd_write;
	reg [4:0] sd_hold;
	reg cpu_took;
	reg cpu_gave;
	reg [3:0] busy_nib;
	reg [9:0] fin_tick;
	wire [11:0] trk_base = (dsided[drv] ? {5'd0, par0[6:0]} * 12'd20 : {5'd0, par0[6:0]} * 12'd10);
	wire [11:0] sect_idx = (trk_base + (dsided[drv] && side ? 12'd10 : 12'd0)) + {4'd0, sector};
	wire sect_ok = ((present[drv] && (par0 < 8'd80)) && (sector < 8'd10)) && (!side || dsided[drv]);
	wire [7:0] steps = (par0 > curtrk ? par0 - curtrk : curtrk - par0);
	wire [15:0] seek_ms = ((steps * step_ms) + (steps != 0 ? settle_ms : 8'd0)) + (motor ? 8'd0 : load_ms);
	wire ev = cpu_ce & cpu_sel;
	wire ev_w = ev & ~cpu_rw;
	wire ev_r = ev & cpu_rw;
	task finish;
		input [7:0] res;
		begin
			result <= res;
			fin_tick <= CRC_TICKS;
			state <= S_FINISH;
		end
	endtask
	always @(posedge clk) begin
		buf_we <= 1'b0;
		if (ce4m) begin
			if (motor)
				rev <= (rev == REV_TICKS ? 20'd0 : rev + 20'd1);
			if ((state == S_IDLE) && motor) begin
				if (unload_cnt != 0)
					unload_cnt <= unload_cnt - 28'd1;
				else begin
					motor <= 1'b0;
					drvout[7:6] <= 2'b00;
				end
			end
		end
		if (ev_r && cpu_addr[2]) begin
			status[ST_INT] <= 1'b0;
			status[ST_NDMA] <= 1'b0;
			cpu_took <= 1'b1;
		end
		if ((ev_r && !cpu_addr[2]) && (cpu_addr[1:0] == 2'd1)) begin
			status[ST_RESF] <= 1'b0;
			status[ST_INT] <= 1'b0;
		end
		if (ev_w && cpu_addr[2]) begin
			data_in <= cpu_din;
			status[ST_INT] <= 1'b0;
			status[ST_NDMA] <= 1'b0;
			cpu_gave <= 1'b1;
		end
		if (((ev_w && !cpu_addr[2]) && (cpu_addr[1:0] == 2'd0)) && !status[ST_BUSY]) begin
			cmd <= cpu_din[5:0];
			pcnt <= 3'd0;
			if (cpu_din[5:0] < 6'h2c)
				drvout[7:6] <= cpu_din[7:6];
			status <= 8'h00 | (8'd1 << ST_BUSY);
			case (cpu_din[5:0])
				6'h2c: preq <= 3'd0;
				6'h29, 6'h3d: preq <= 3'd1;
				6'h0a, 6'h0e, 6'h12, 6'h16, 6'h1e, 6'h3a: preq <= 3'd2;
				6'h0b, 6'h0f, 6'h13, 6'h17, 6'h1f, 6'h1b: preq <= 3'd3;
				6'h35: preq <= 3'd4;
				6'h00, 6'h04, 6'h23: preq <= 3'd5;
				default: preq <= 3'd0;
			endcase
			state <= S_IDLE;
		end
		if ((((ev_w && !cpu_addr[2]) && (cpu_addr[1:0] == 2'd1)) && status[ST_BUSY]) && (pcnt < preq)) begin
			case (pcnt)
				3'd0: par0 <= cpu_din;
				3'd1: par1 <= cpu_din;
				3'd2: par2 <= cpu_din;
				3'd3: par3 <= cpu_din;
				default: par4 <= cpu_din;
			endcase
			pcnt <= pcnt + 3'd1;
		end
		if ((((state == S_IDLE) && status[ST_BUSY]) && (pcnt == preq)) && !ev) begin
			pcnt <= 3'd7;
			case (cmd)
				6'h2c: begin
					result <= (((8'h80 | (drvout[7] ? 8'h40 : 8'h00)) | (index ? 8'h10 : 8'h00)) | (drvout[6] ? 8'h04 : 8'h00)) | (phys == 7'd0 ? 8'h02 : 8'h00);
					status <= 8'h00 | (8'd1 << ST_RESF);
				end
				6'h35: begin
					if (par0 == 8'h0d) begin
						step_ms <= par1;
						settle_ms <= par2;
						unload_revs <= par3[7:4];
						load_ms <= {3'd0, par3[3:0], 1'b0};
					end
					status <= 8'h00;
				end
				6'h3a: begin
					case (par0)
						8'h12: curtrk0 <= par1;
						8'h1a: curtrk1 <= par1;
						8'h23: drvout <= par1;
						default:
							;
					endcase
					status <= 8'h00;
				end
				6'h3d: begin
					case (par0)
						8'h12: result <= curtrk0;
						8'h1a: result <= curtrk1;
						8'h23: result <= drvout;
						default: result <= 8'h00;
					endcase
					status <= 8'h00 | (8'd1 << ST_RESF);
				end
				6'h29, 6'h0a, 6'h0b, 6'h0e, 6'h0f, 6'h12, 6'h13, 6'h16, 6'h17, 6'h1e, 6'h1f, 6'h1b, 6'h23: begin
					case (cmd)
						6'h29: begin
							op <= OP_SEEK;
							busy_nib <= 4'h1;
						end
						6'h0a, 6'h0b, 6'h0e, 6'h0f: begin
							op <= OP_WRITE;
							busy_nib <= 4'ha;
						end
						6'h1e, 6'h1f: begin
							op <= OP_VERIFY;
							busy_nib <= 4'h8;
						end
						6'h1b: begin
							op <= OP_READID;
							busy_nib <= 4'he;
						end
						6'h23: begin
							op <= OP_FORMAT;
							busy_nib <= 4'hf;
						end
						default: begin
							op <= OP_READ;
							busy_nib <= 4'h8;
						end
					endcase
					if ((((cmd[0] == 1'b0) && (cmd != 6'h1b)) && (cmd != 6'h29)) && (cmd != 6'h23)) begin
						nleft <= 5'd1;
						nbytes <= 9'd128;
					end
					else begin
						nleft <= par2[4:0];
						nbytes <= (par2[7:5] == 3'd0 ? 9'd128 : 9'd256);
					end
					sector <= par1;
					result <= R_OK;
					id_sector <= rot_sector;
					motor <= 1'b1;
					if (new_phys != phys) begin
						seek_n <= (new_phys > phys ? new_phys - phys : phys - new_phys);
						seek_tog <= ~seek_tog;
					end
					if (drv) begin
						curtrk1 <= par0;
						phys1 <= (par0 > 8'd81 ? 7'd81 : par0[6:0]);
					end
					else begin
						curtrk0 <= par0;
						phys0 <= (par0 > 8'd81 ? 7'd81 : par0[6:0]);
					end
					delay_ms <= seek_ms;
					ms_sub <= MS_TICKS;
					next_state <= (cmd == 6'h29 ? S_DONE : S_SECTOR);
					state <= S_DELAY;
				end
				default: begin
					result <= R_NOT_FOUND;
					status <= (8'h00 | (8'd1 << ST_RESF)) | (8'd1 << ST_INT);
				end
			endcase
		end
		case (state)
			S_IDLE:
				;
			S_DELAY:
				if (ce4m) begin
					if (ms_sub != 0)
						ms_sub <= ms_sub - 12'd1;
					else if (delay_ms != 0) begin
						delay_ms <= delay_ms - 16'd1;
						ms_sub <= MS_TICKS;
					end
					else
						state <= next_state;
				end
			S_SECTOR:
				if (op == OP_READID) begin
					if (!present[drv] || (side && !dsided[drv])) begin
						delay_ms <= 16'd400;
						ms_sub <= MS_TICKS;
						next_state <= S_DONE;
						result <= R_NOT_FOUND;
						state <= S_DELAY;
					end
					else if (nleft == 0)
						finish(R_OK);
					else begin
						idb <= 2'd0;
						byte_tick <= BYTE_TICKS;
						state <= S_ID_TAKEN;
						cpu_took <= 1'b1;
					end
				end
				else if (op == OP_FORMAT) begin
					if (!present[drv] || (side && !dsided[drv])) begin
						delay_ms <= 16'd400;
						ms_sub <= MS_TICKS;
						next_state <= S_DONE;
						result <= R_NOT_FOUND;
						state <= S_DELAY;
					end
					else if (nleft == 0)
						finish(R_OK);
					else begin
						idb <= 2'd0;
						byte_tick <= BYTE_TICKS;
						state <= S_FMT_ASK;
					end
				end
				else if (!sect_ok) begin
					delay_ms <= 16'd400;
					ms_sub <= MS_TICKS;
					next_state <= S_DONE;
					result <= R_NOT_FOUND;
					state <= S_DELAY;
				end
				else if (op == OP_VERIFY) begin
					byte_tick <= BYTE_TICKS;
					bcnt <= 9'd0;
					state <= S_VERIFY;
				end
				else begin
					ext_drive <= drv;
					ext_lba <= {21'd0, sect_idx[11:1]};
					half <= sect_idx[0];
					sd_write <= 1'b0;
					sd_next <= (op == OP_WRITE ? S_WR_ASK : S_RD_FETCH);
					bcnt <= 9'd0;
					byte_tick <= BYTE_TICKS;
					cpu_gave <= 1'b0;
					state <= S_SD_START;
				end
			S_SD_START: begin
				if (sd_write)
					ext_wr <= 1'b1;
				else
					ext_rd <= 1'b1;
				sd_hold <= 5'd31;
				state <= S_SD_WAIT;
			end
			S_SD_WAIT:
				if (sd_hold != 0)
					sd_hold <= sd_hold - 5'd1;
				else if (!sd_busy) begin
					ext_rd <= 1'b0;
					ext_wr <= 1'b0;
					state <= sd_next;
				end
			S_RD_FETCH: begin
				buf_addr <= {half, bcnt[7:0]};
				state <= S_RD_FETCH2;
			end
			S_RD_FETCH2: state <= S_RD_OFFER;
			S_RD_OFFER:
				if (ce4m) begin
					if (byte_tick != 0)
						byte_tick <= byte_tick - 9'd1;
					else begin
						data_out <= buf_q;
						status <= ((8'h00 | (8'd1 << ST_BUSY)) | (8'd1 << ST_INT)) | (8'd1 << ST_NDMA);
						cpu_took <= 1'b0;
						bcnt <= bcnt + 9'd1;
						byte_tick <= BYTE_TICKS;
						state <= S_RD_TAKEN;
					end
				end
			S_RD_TAKEN:
				if (cpu_took) begin
					if (bcnt == nbytes)
						state <= S_NEXT;
					else
						state <= S_RD_FETCH;
				end
			S_WR_ASK:
				if (ce4m) begin
					if (byte_tick != 0)
						byte_tick <= byte_tick - 9'd1;
					else begin
						status <= ((8'h00 | (8'd1 << ST_BUSY)) | (8'd1 << ST_INT)) | (8'd1 << ST_NDMA);
						cpu_gave <= 1'b0;
						byte_tick <= BYTE_TICKS;
						state <= S_WR_WAIT;
					end
				end
			S_WR_WAIT:
				if (cpu_gave) begin
					buf_addr <= {half, bcnt[7:0]};
					buf_din <= data_in;
					buf_we <= 1'b1;
					bcnt <= bcnt + 9'd1;
					if ((bcnt + 9'd1) == nbytes)
						state <= S_WR_FLUSH;
					else
						state <= S_WR_ASK;
				end
			S_WR_FLUSH: begin
				sd_write <= 1'b1;
				sd_next <= S_NEXT;
				state <= S_SD_START;
			end
			S_VERIFY:
				if (ce4m) begin
					if (byte_tick != 0)
						byte_tick <= byte_tick - 9'd1;
					else begin
						byte_tick <= BYTE_TICKS;
						bcnt <= bcnt + 9'd1;
						if ((bcnt + 9'd1) == nbytes)
							state <= S_NEXT;
					end
				end
			S_NEXT:
				if (nleft <= 5'd1)
					finish(R_OK);
				else begin
					nleft <= nleft - 5'd1;
					sector <= sector + 8'd1;
					state <= S_SECTOR;
				end
			S_DONE:
				finish(result);
			S_FINISH:
				if (ce4m) begin
					if (fin_tick != 0)
						fin_tick <= fin_tick - 10'd1;
					else begin
						status <= (8'h00 | (8'd1 << ST_RESF)) | (8'd1 << ST_INT);
						state <= S_IDLE;
						unload_cnt <= (unload_revs == 4'd0 ? 28'd1 : {24'd0, unload_revs}) * (REV_TICKS + 28'd1);
					end
				end
			S_ID_TAKEN:
				if (cpu_took && ce4m) begin
					if (byte_tick != 0)
						byte_tick <= byte_tick - 9'd1;
					else begin
						case (idb)
							2'd0: data_out <= par0;
							2'd1: data_out <= 8'h00;
							2'd2: data_out <= {4'd0, id_sector};
							default: data_out <= 8'h01;
						endcase
						status <= ((8'h00 | (8'd1 << ST_BUSY)) | (8'd1 << ST_INT)) | (8'd1 << ST_NDMA);
						cpu_took <= 1'b0;
						byte_tick <= BYTE_TICKS;
						idb <= idb + 2'd1;
						if (idb == 2'd3) begin
							id_sector <= (id_sector == 4'd9 ? 4'd0 : id_sector + 4'd1);
							nleft <= nleft - 5'd1;
							state <= S_ID_OFFER;
						end
					end
				end
			S_FMT_ASK:
				if (ce4m) begin
					if (byte_tick != 0)
						byte_tick <= byte_tick - 9'd1;
					else begin
						status <= ((8'h00 | (8'd1 << ST_BUSY)) | (8'd1 << ST_INT)) | (8'd1 << ST_NDMA);
						cpu_gave <= 1'b0;
						byte_tick <= BYTE_TICKS;
						state <= S_FMT_WAIT;
					end
				end
			S_FMT_WAIT:
				if (cpu_gave) begin
					idb <= idb + 2'd1;
					if (idb == 2'd2)
						fmt_id <= data_in;
					if (idb == 2'd3) begin
						sector <= fmt_id;
						state <= S_FMT_FILL;
					end
					else
						state <= S_FMT_ASK;
				end
			S_FMT_FILL:
				if (sect_ok) begin
					ext_drive <= drv;
					ext_lba <= {21'd0, sect_idx[11:1]};
					half <= sect_idx[0];
					sd_write <= 1'b0;
					sd_next <= S_FMT_PUT;
					bcnt <= 9'd0;
					state <= S_SD_START;
				end
				else
					state <= S_FMT_NEXT;
			S_FMT_PUT: begin
				buf_addr <= {half, bcnt[7:0]};
				buf_din <= 8'he5;
				buf_we <= 1'b1;
				bcnt <= bcnt + 9'd1;
				if (bcnt == 9'd255) begin
					sd_write <= 1'b1;
					sd_next <= S_FMT_NEXT;
					state <= S_SD_START;
				end
			end
			S_FMT_NEXT: begin
				nleft <= nleft - 5'd1;
				state <= S_SECTOR;
			end
			S_ID_OFFER:
				if (cpu_took)
					state <= S_SECTOR;
			default: state <= S_IDLE;
		endcase
		if ((((ev_w && !cpu_addr[2]) && (cpu_addr[1:0] == 2'd2)) && cpu_din[0]) || reset) begin
			status <= 8'h00;
			result <= 8'h00;
			state <= S_IDLE;
			pcnt <= 3'd0;
			preq <= 3'd0;
			cmd <= 6'h3f;
			curtrk0 <= 8'd0;
			curtrk1 <= 8'd0;
			ext_rd <= 1'b0;
			ext_wr <= 1'b0;
			cpu_took <= 1'b1;
			cpu_gave <= 1'b0;
		end
		if (reset) begin
			drvout <= 8'h00;
			phys0 <= 7'd0;
			phys1 <= 7'd0;
			seek_tog <= 1'b0;
			seek_n <= 7'd0;
			motor <= 1'b0;
			rev <= 20'd0;
			unload_cnt <= 28'd0;
			step_ms <= 8'd12;
			settle_ms <= 8'd10;
			load_ms <= 8'd16;
			unload_revs <= 4'd12;
			busy_nib <= 4'd0;
		end
	end
	assign disk_info = {motor, motor, status[ST_BUSY], drv, ~side, busy_nib, phys, sector};
endmodule
