`timescale 1ns / 1ps
`default_nettype wire

/*
 BBC Micro core for Karabas Mini rev.G (HDMI, PCM5102): bbc_micro_core of BeebFpga (dev, hoglet67)
 as Model B (T65) and Master 128 (AlanD 65C02) in one bitstream, with the board glue of
 karabas-go-modules.

 Clocks (bbc_clocks): clk_48 48 MHz (the machine, the SRAM, the MCU link, the DAC), clk_27 27 MHz
 (the line doubler of the core, the OSD, HDMI), clk_135 / clk_135_n (the serialiser), clk_8
 (FT_CLK_OUT). clk_48 and clk_27 are from two PLLs: the paths between them are not timed, the core
 and the modules cross them by design (dual clock RAMs, synchronisers, values that are stable).

 Memory (bbc_mem): the external bus of the core (512 KB) on the SRAM, a bank of 512 KB per model,
 the disc filing system ROMs (fs.rom) mapped onto their slots by the OSD choice; the ROM images
 (roms/kg, tools/bbc_roms.sh) come from the .kg when the core starts, the machine is held in reset
 while they load.

 Discs: .ssd / .dsd images of the SD card through the file mounter of kg_mcu2 (F items Drive 0 / 1 =
 slots 0 / 1, bbc_sd_sdc) on the 1770 (Master, Model B with B FDC 1770) or the 8271 (Model B) of the
 core (KgFdc, Welsh71).

 SD2 (the second card, on the FPGA pins): MMFS / MMFS2 of the core drive it themselves (IncludeSPISD,
 a BEEB.MMB file or .ssd files on a FAT card): kg_mcu2 has no SD2 here (ENABLE_SD2 0).

 Video: 720 x 576p50 from the scan doubler of the core (bbc_video_out: own syncs, de), the OSD of
 link v2 over it, HDMI with audio. Syncs negative.

 Audio: the mix of the core (SN76489 + SID + Music 5000, 16 bits signed) to the PCM5102 and HDMI (48 kHz).

 Keyboard: the PS/2 set 2 bytes of kg_mcu2 straight into the keyboard matrix of the core
 (KgExtKeyboard): F12 = BREAK, the rest as BeebFpga. Joystick 1 / 2: the first and second pad.

 Soft switches (the index of the item in the osd of core.json, "index"):
   0 Model (Model B / Master 128)   1 Disc FS (MMFS / MMFS2 / DFS / MMFS+DFS / MMFS2+DFS: the ROMs
   in their slots; MMFS on SD2, DFS on the images)   2 B FDC (8271 / 1770, Model B)   3 Co-processor
   (Off / 65C02)   4 Reset (a power-on reset)
 A change of Model, Disc FS, B FDC or Co-processor resets the machine.
*/

module karabas_minig_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,

	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [5:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign ESP32_SPI_CS_N = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;

assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;
assign MIDI_TX = 1'b1;

// the SDRAM is not used: no clock, deselected by its commands (NOP: RAS / CAS / WE high)
assign SDR_A = 13'd0;
assign SDR_BA = 2'b00;
assign SDR_CLK = 1'b0;
assign SDR_DQM = 2'b11;
assign SDR_WE_N = 1'b1;
assign SDR_CAS_N = 1'b1;
assign SDR_RAS_N = 1'b1;
assign SDR_DQ = 16'bz;

// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board): always selected
assign FLASH_CS_N = 1'b0;
assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_48, clk_27, clk_135, clk_135_n, clk_8, pll_locked;
bbc_clocks clocks (
	.clk_in(CLK_50MHZ),
	.clk_48(clk_48),
	.clk_27(clk_27),
	.clk_135(clk_135),
	.clk_135_n(clk_135_n),
	.clk_8(clk_8),
	.locked(pll_locked)
);
(* KEEP = "TRUE" *) wire areset_async = ~pll_locked;
wire areset, areset_27;
kg_sync #(.W(1), .STAGES(2), .INIT(1'b1)) sync_areset (.clk(clk_48), .d(areset_async), .q(areset));
kg_sync #(.W(1), .STAGES(2), .INIT(1'b1)) sync_areset_27 (.clk(clk_27), .d(areset_async), .q(areset_27));

// the clock of the FT812
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ MCU

wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));

// karabas: MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire [15:0] joy_l, joy_r;
wire [7:0] ps2_code;
wire ps2_kind, ps2_wr;
wire [1:0] ld_kind;
wire [7:0] ld_data;
wire [31:0] ld_addr;
wire ld_active, ld_wr;
wire [8*8-1:0] sw;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on;
wire [15:0] dbg_addr;
reg [15:0] dbg_data = 16'd0;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;
wire [7:0] sdc_img_mounted, img_wp, sdc_rd, sdc_wr, sdc_byte_in_data, sdc_byte_out_data;
wire [63:0] sdc_img_size;
wire [31:0] sdc_sector;
wire sdc_busy, sdc_done, sdc_byte_in_strobe;
wire [2:0] sdc_slot;
wire [8:0] sdc_byte_addr;

kg_mcu2 #(
	.SW_N(8),
	.CS_FILTER(3),
	.CAPS(16'h0004),     // bit 2: write protected images
	.ENABLE_OSD(1),
	.ENABLE_IMG(1),
	.IMG_OUT_LATENCY(3), // the address register of kg_l2_img, the buffer RAM of fdc1772, the register of bbc_sd_sdc
	.ENABLE_AUX(1),      // DEBUG_*: the state of the core (AT+KARABAS=debug:1, kg_board.py log)
	.ENABLE_FT(1),
	.ENABLE_SD2(0)       // SD2 belongs to the core (MMFS)
) mcu (
	.CLK(clk_48),
	.N_RESET(~areset),

	.MCU_SCK(mcu_sck),
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SS(MCU_CS_N),
	.MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(MCU_IO[3]),
	.MCU_SPI_SD2_SS(1'b1),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(dvi_only), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD(), .KBD_WR(),
	.PS2_CODE(ps2_code), .PS2_KIND(ps2_kind), .PS2_WR(ps2_wr),
	.MS_X(), .MS_Y(), .MS_Z(), .MS_B(), .MS_WR(),
	.JOY_L(joy_l), .JOY_R(joy_r), .JOY_WR(),
	.PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(ld_kind), .LD_SLOT(), .LD_SIZE(), .LD_EXT(), .LD_START(), .LD_ACTIVE(ld_active), .LD_END(),
	.LD_ADDR(ld_addr), .LD_DATA(ld_data), .LD_WR(ld_wr), .LD_READY(1'b1),

	.OSD_WR(osd_wr), .OSD_WADDR(osd_waddr), .OSD_WDATA(osd_wdata), .OSD_EN(osd_en),
	.OSD_FG(osd_fg), .OSD_BG(osd_bg), .OSD_ALPHA(osd_alpha), .OSD_PX(osd_px), .OSD_PY(osd_py),
	.OSD_PW(osd_pw), .OSD_PH(osd_ph), .OSD_PLACE(osd_place), .OSD_ZOOM(osd_zoom),

	.SDC_IMG_MOUNTED(sdc_img_mounted), .SDC_IMG_SIZE(sdc_img_size), .SDC_RD(sdc_rd), .SDC_WR(sdc_wr),
	.SDC_SECTOR(sdc_sector), .SDC_BUSY(sdc_busy), .SDC_DONE(sdc_done), .SDC_ERROR(), .SDC_SLOT(sdc_slot),
	.SDC_BYTE_IN_STROBE(sdc_byte_in_strobe), .SDC_BYTE_ADDR(sdc_byte_addr), .SDC_BYTE_IN_DATA(sdc_byte_in_data),
	.SDC_BYTE_OUT_DATA(sdc_byte_out_data), .IMG_WP(img_wp), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0), .IMG_ACTIVE(),
	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'b1111), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_CFG(128'd0), .PORT_IN_FULL(), .PORT_STAT(), .PORT_STAT_WR(),
	.RTC_A(8'd0), .RTC_DI(8'd0), .RTC_CS(1'b0), .RTC_WR_N(1'b1), .MATRIX_CMD(24'd0), .MATRIX_CMD_WR(1'b0),
	.DEBUG_ADDR(dbg_addr), .DEBUG_DATA(dbg_data), .RTC_DO(),

	.FT_SPI_ON(ft_spi_on), .FT_VGA_ON(), .FT_RESET(), .FT_SCK(), .FT_MOSI(ft_mosi), .FT_MISO(FT_SPI_MISO),
	.FT_CS_N(ft_cs_n),
	.SD2_SCK(), .SD2_MOSI(), .SD2_MISO(1'b1), .SD2_CS_N()
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;

// ------------------------------------------------------------------ soft switches, reset

wire sw_master = sw[0*8];
wire [2:0] sw_fs = sw[1*8 +: 3];
wire sw_1770 = sw[2*8];
wire sw_copro = sw[3*8];
wire sw_reset = sw[4*8];

wire loading;

// the model and the filing system are taken while the machine is in reset; a change of either
// (or the Reset item, or a ROM load) gives a power-on reset of about 1.4 ms (16 bits of clk_48,
// as the reset counters of BeebFpga)
reg m128_mode = 1'b0, copro_mode = 1'b0, fdc_8271 = 1'b1;
reg [2:0] fs = 3'd3;
reg [15:0] rst_cnt = 16'd0;
reg powerup_reset_n = 1'b0;
always @(posedge clk_48) begin
	if (areset || loading || sw_reset || sw_master != m128_mode || sw_fs != fs || sw_1770 == fdc_8271 || sw_copro != copro_mode) begin
		rst_cnt <= 16'd0;
		m128_mode <= sw_master;
		fs <= sw_fs;
		fdc_8271 <= !sw_1770;
		copro_mode <= sw_copro;
	end
	else if (!rst_cnt[15])
		rst_cnt <= rst_cnt + 16'd1;
	powerup_reset_n <= rst_cnt[15];
end
wire hard_reset_n = powerup_reset_n;

// Disc FS: 0 MMFS, 1 MMFS2, 2 DFS, 3 MMFS+DFS, 4 MMFS2+DFS
wire fs_mmfs = fs != 3'd2;
wire fs_mmfs2 = fs == 3'd1 || fs == 3'd4;
wire fs_dfs = fs >= 3'd2;

// ------------------------------------------------------------------ the core

wire [3:0] vga_r, vga_g, vga_b;
wire vga_hs, vga_vs;
wire [15:0] audio_l, audio_r;
wire [18:0] ext_a;
wire ext_ncs, ext_noe, ext_nwe;
wire [7:0] ext_din, ext_dout;
wire sd_ss, sd_clk, sd_mosi;
wire caps_led, shift_led, motor_led;
wire cas_out;
wire [15:0] cpu_addr;
wire floppy_led;

// disc images: the file mounter of kg_mcu2 (slots 0 / 1) -> the MiSTer sector interface
wire [31:0] sd_lba;
wire [1:0] sd_rd, sd_wr, sd_ack, img_mounted;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout, sd_buff_din;
wire sd_buff_wr, img_readonly;
wire [63:0] img_size;
bbc_sd_sdc disks (
	.clk(clk_48),
	.reset(areset),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),
	.sdc_img_mounted(sdc_img_mounted),
	.sdc_img_size(sdc_img_size),
	.img_wp(img_wp),
	.sdc_rd(sdc_rd),
	.sdc_wr(sdc_wr),
	.sdc_sector(sdc_sector),
	.sdc_busy(sdc_busy),
	.sdc_done(sdc_done),
	.sdc_slot(sdc_slot),
	.sdc_byte_in_strobe(sdc_byte_in_strobe),
	.sdc_byte_addr(sdc_byte_addr),
	.sdc_byte_in_data(sdc_byte_in_data),
	.sdc_byte_out_data(sdc_byte_out_data)
);

// the write protection of each drive, taken at its mount (img_size / img_readonly come with
// img_mounted one clock later than the mounter pulse: as bbc_sd_sdc registers them together)
reg [1:0] drive_wp = 2'b00;
always @(posedge clk_48) begin
	if (img_mounted[0]) drive_wp[0] <= img_readonly;
	if (img_mounted[1]) drive_wp[1] <= img_readonly;
end

// joystick: bits 0 up, 1 down, 2 left, 3 right, 4 fire, low active (pad: 1 up, 2 down, 3 left,
// 4 right, 6 A, 7 B)
wire [4:0] joy1_n = ~{ joy_l[6] | joy_l[7], joy_l[4], joy_l[3], joy_l[2], joy_l[1] };
wire [4:0] joy2_n = ~{ joy_r[6] | joy_r[7], joy_r[4], joy_r[3], joy_r[2], joy_r[1] };

// keyboard bytes: PS/2 set 2 only (kind 0)
wire kbd_valid = ps2_wr && !ps2_kind;

bbc_kg_core core (
	.clock_27(clk_27),
	.clock_48(clk_48),
	.hard_reset_n(hard_reset_n),
	.powerup_reset_n(powerup_reset_n),
	.m128_mode(m128_mode),
	.copro_mode(copro_mode),
	.kbd_data(ps2_code),
	.kbd_valid(kbd_valid),
	.caps_led(caps_led),
	.shift_led(shift_led),
	.motor_led(motor_led),
	.joystick1(joy1_n),
	.joystick2(joy2_n),
	.vga_red(vga_r),
	.vga_green(vga_g),
	.vga_blue(vga_b),
	.vga_hsync(vga_hs),
	.vga_vsync(vga_vs),
	.audio_l(audio_l),
	.audio_r(audio_r),
	.ext_nOE(ext_noe),
	.ext_nWE(ext_nwe),
	.ext_nCS(ext_ncs),
	.ext_A(ext_a),
	.ext_Dout(ext_dout),
	.ext_Din(ext_din),
	.SDMISO(SD_DO),
	.SDSS(sd_ss),
	.SDCLK(sd_clk),
	.SDMOSI(sd_mosi),
	.cas_in(1'b1),
	.cas_out(cas_out),
	.cpu_addr(cpu_addr),
	.fdc_8271(fdc_8271),
	.img_mounted(img_mounted),
	.img_wp(drive_wp),
	.img_size(img_size[31:0]),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(|sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_buff_dout),
	.sd_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),
	.floppy_led(floppy_led)
);

assign SD_CS_N = sd_ss;
assign SD_CLK = sd_clk;
assign SD_DI = sd_mosi;
assign TAPE_OUT = cas_out;

// ------------------------------------------------------------------ memory

wire [15:0] sram_md_o;
wire sram_md_oe;
bbc_mem mem (
	.clk(clk_48),
	.m128(m128_mode),
	.fs_mmfs(fs_mmfs),
	.fs_mmfs2(fs_mmfs2),
	.fs_dfs(fs_dfs),
	.fdc_8271(fdc_8271),
	.ext_a(ext_a),
	.ext_ncs(ext_ncs),
	.ext_noe(ext_noe),
	.ext_nwe(ext_nwe),
	.ext_din(ext_din),
	.ext_dout(ext_dout),
	.ld_kind(ld_kind),
	.ld_active(ld_active),
	.ld_wr(ld_wr),
	.ld_addr(ld_addr),
	.ld_data(ld_data),
	.loading(loading),
	.MA(MA),
	.MD_I(MD),
	.MD_O(sram_md_o),
	.MD_OE(sram_md_oe),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);
assign MD = sram_md_oe ? sram_md_o : 16'bz;

// ------------------------------------------------------------------ video

wire [23:0] vid_rgb;
wire vid_hs, vid_vs, vid_de;
bbc_video_out video_out (
	.clk(clk_27),
	.r_i(vga_r),
	.g_i(vga_g),
	.b_i(vga_b),
	.hs_i(vga_hs),
	.vs_i(vga_vs),
	.rgb(vid_rgb),
	.hs(vid_hs),
	.vs(vid_vs),
	.de(vid_de)
);

// the bitmap OSD of link v2 (kg_l2_osd_overlay): centred in de, the scale from its size,
// 2 clocks of latency with its syncs and de
wire [23:0] osd_rgb;
wire osd_hs, osd_vs, osd_de;
kg_l2_osd_overlay osd (
	.wclk(clk_48),
	.osd_wr(osd_wr), .osd_waddr(osd_waddr), .osd_wdata(osd_wdata), .osd_en(osd_en),
	.osd_fg(osd_fg), .osd_bg(osd_bg), .osd_alpha(osd_alpha), .osd_px(osd_px), .osd_py(osd_py),
	.osd_pw(osd_pw), .osd_ph(osd_ph), .osd_place(osd_place), .osd_zoom(osd_zoom),
	.icon_on(8'd0), .icon_act(8'd0),
	.clk(clk_27),
	.rgb_i(vid_rgb), .hs_i(vid_hs), .vs_i(vid_vs), .de_i(vid_de),
	.rgb_o(osd_rgb), .hs_o(osd_hs), .vs_o(osd_vs), .de_o(osd_de)
);

// ------------------------------------------------------------------ audio

kg_pcm5102 #(.DIV_BITS(3)) dac (  // bck 3 MHz, 93.75 kHz
	.clk(clk_48),
	.reset(areset),
	.left(audio_l),
	.right(audio_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);

// 48 kHz for HDMI: a sample every 1000 clk_48 (exact), held in clk_48 and taken in clk_27 on the
// toggle (stable for 1000 clocks)
reg [9:0] aud_div = 10'd0;
reg aud_tgl = 1'b0;
reg [15:0] aud_l48 = 16'd0, aud_r48 = 16'd0;
always @(posedge clk_48) begin
	if (aud_div == 10'd999) begin
		aud_div <= 10'd0;
		aud_l48 <= audio_l;
		aud_r48 <= audio_r;
		aud_tgl <= ~aud_tgl;
	end
	else
		aud_div <= aud_div + 10'd1;
end

reg [2:0] aud_tgl_s = 3'b000;
reg aud_stb = 1'b0;
reg [23:0] hdmi_l = 24'd0, hdmi_r = 24'd0;
always @(posedge clk_27) begin
	aud_tgl_s <= { aud_tgl_s[1:0], aud_tgl };
	aud_stb <= aud_tgl_s[2] ^ aud_tgl_s[1];
	if (aud_tgl_s[2] ^ aud_tgl_s[1]) begin
		hdmi_l <= { aud_l48, 8'd0 };
		hdmi_r <= { aud_r48, 8'd0 };
	end
end

// ------------------------------------------------------------------ HDMI

reg dvi_only_p = 1'b0;
always @(posedge clk_27)
	dvi_only_p <= dvi_only;

// negative syncs
reg hdmi_hs = 1'b1, hdmi_vs = 1'b1, hdmi_de = 1'b0;
reg [23:0] hdmi_rgb = 24'd0;
always @(posedge clk_27) begin
	hdmi_hs <= ~osd_hs;
	hdmi_vs <= ~osd_vs;
	hdmi_de <= osd_de;
	hdmi_rgb <= osd_rgb;
end

hdmi_tx #(.SAMPLE_FREQ(48000)) hdmi (
	.clk(clk_27),
	.sclk(clk_135),
	.sclk_n(clk_135_n),
	.reset(areset_27),
	.rgb(hdmi_rgb),
	.vsync(hdmi_vs),
	.hsync(hdmi_hs),
	.de(hdmi_de),
	.audio_en(~dvi_only_p),
	.audio_l(hdmi_l),
	.audio_r(hdmi_r),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

// ------------------------------------------------------------------ debug

// DEBUG_ADDR: the address of the CPU; DEBUG_DATA: { loading, reset_n, m128, copro, 8271, fs, leds,
// floppy led, sd_rd, sd_ack }
assign dbg_addr = cpu_addr;
always @(posedge clk_48)
	dbg_data <= { loading, hard_reset_n, m128_mode, copro_mode, fdc_8271, fs, caps_led, shift_led, motor_led, floppy_led, sd_rd, sd_ack };

endmodule
