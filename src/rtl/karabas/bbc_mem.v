`timescale 1ns / 1ps
`default_nettype wire
/*
 bbc_mem.v

 The board SRAM (two 2M x 8 chips = 2M x 16, 10 ns, asynchronous; MWR_N / MRD_N [0] = MD[7:0],
 [1] = MD[15:8]) on the external memory bus of bbc_micro_core (BeebFpga: 8 bits, 512 KB, ext_A 19 bits,
 the map in the core above its "SRAM bus" process: 0x00000-0x3FFFF ROM, 0x40000-0x7FFFF RAM), and the
 loader of the ROMs of the .kg (link v2 LOAD kind 0, ld_*).

 A bank of 512 KB per model: the byte address is { 0, m128, ext_A } (tools/bbc_roms.sh):
   0x000000 Model B (ROM images 0x00000-0x3FFFF, RAM above)   0x080000 Master 128 (the same)
 The filing system ROMs are one copy each at 0x100000 (fs.rom, 16 KB slots), and the ROM slots of
 the disc filing systems are mapped onto them (as rom_addr of Welsh71/BBCMicro.Alternate_MiSTer):
   Model B slot 3: DFS 1.20 (8271) / DFS 2.26 (1770) / blank    slot 8: SWMMFS / SWMMFS2 / blank
   Master  slot 8: DFS 2.24 / blank                               slot 9: MAMMFS / MAMMFS2 / blank
   fs.rom: 0 SWMMFS, 1 SWMMFS2, 2 DNFS 1.20, 3 DFS 2.26, 4 MAMMFS, 5 MAMMFS2, 6 DFS 2.24 (Master), 7 blank
 (the upper part of Model B slot 8 that SWMMFS uses as RAM is in the RAM half, ext_A[18] = 1: not
 mapped). A change of model or filing system is a power-on reset of the machine anyway.

 The core bus is registered in the core on clk (48 MHz) and goes to the pins through one level of
 logic (lanes, the loader mux). The core latches the read data at the end of its 6-clock memory slot
 and strobes nWE for one clock in the middle of it, with the address and the data stable around it
 (the same bus drives the SRAM of the Spec Next directly): the SRAM paths are multicycle.

 The loader: while a LOAD of kind 0 is open (loading) the top holds the machine in reset (its ext_nCS
 is high then) and each LD_WR byte is written in 3 clocks: address and data out, /WE low, /WE high.
 The link gives a byte at most every 8 MCU clocks (250 ns at 32 MHz): no back pressure (ld_ready 1).
*/
module bbc_mem (
	input wire clk,

	// the core (bbc_micro_core ext_*)
	input wire m128,
	input wire fs_mmfs,           // an MMFS ROM in its slot
	input wire fs_mmfs2,          // MMFS2 instead of MMFS
	input wire fs_dfs,            // a DFS ROM in its slot
	input wire fdc_8271,          // Model B: DFS 1.20 (8271), else DFS 2.26 (1770)
	input wire [18:0] ext_a,
	input wire ext_ncs,
	input wire ext_noe,
	input wire ext_nwe,
	input wire [7:0] ext_din,
	output wire [7:0] ext_dout,

	// the loader (kg_mcu2 LD_*)
	input wire [1:0] ld_kind,
	input wire ld_active,
	input wire ld_wr,
	input wire [31:0] ld_addr,
	input wire [7:0] ld_data,
	output wire loading,

	// the pins
	output wire [20:0] MA,
	input wire [15:0] MD_I,
	output wire [15:0] MD_O,
	output wire MD_OE,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N
);

assign loading = ld_active && ld_kind == 2'd0;

// ---------------------------------------------------------------- the loader

reg [20:0] l_addr = 21'd0;   // byte address
reg [7:0] l_data = 8'd0;
reg l_setup = 1'b0;          // clock 1: address and data on the bus
reg l_we = 1'b0;             // clock 2: /WE low (clock 3: /WE high, the bus still holds the byte)
always @(posedge clk) begin
	l_setup <= 1'b0;
	l_we <= l_setup;
	if (ld_wr && loading) begin
		l_addr <= ld_addr[20:0];
		l_data <= ld_data;
		l_setup <= 1'b1;
	end
end

// ---------------------------------------------------------------- the bus

// the filing system ROM slots
wire [3:0] slot = ext_a[17:14];
reg [2:0] fs_slot;
reg fs_map;
always @* begin
	fs_map = 1'b0;
	fs_slot = 3'd7;
	if (!ext_a[18]) begin
		if (!m128 && slot == 4'd3) begin
			fs_map = 1'b1;
			fs_slot = !fs_dfs ? 3'd7 : fdc_8271 ? 3'd2 : 3'd3;
		end
		else if (!m128 && slot == 4'd8) begin
			fs_map = 1'b1;
			fs_slot = !fs_mmfs ? 3'd7 : fs_mmfs2 ? 3'd1 : 3'd0;
		end
		else if (m128 && slot == 4'd8) begin
			fs_map = 1'b1;
			fs_slot = fs_dfs ? 3'd6 : 3'd7;
		end
		else if (m128 && slot == 4'd9) begin
			fs_map = 1'b1;
			fs_slot = !fs_mmfs ? 3'd7 : fs_mmfs2 ? 3'd5 : 3'd4;
		end
	end
end

wire [20:0] a = loading ? l_addr : fs_map ? { 4'b1000, fs_slot, ext_a[13:0] } : { 1'b0, m128, ext_a };
wire lane = a[0];
wire rd = !loading && !ext_ncs && !ext_noe;
wire wr = loading ? l_we : (!ext_ncs && !ext_nwe);
wire [7:0] wdata = loading ? l_data : ext_din;

assign MA = { 1'b0, a[20:1] };
assign MRD_N = { !(rd && lane), !(rd && !lane) };
assign MWR_N = { !(wr && lane), !(wr && !lane) };
assign MD_O = { wdata, wdata };
assign MD_OE = wr;
assign ext_dout = lane ? MD_I[15:8] : MD_I[7:0];

endmodule
