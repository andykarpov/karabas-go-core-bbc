`timescale 1ns / 1ps
// A behavioural SDR SDRAM for the tests: 16 bits, CAS latency 2, burst 1, commands on the rising
// edge of its clock (the boards feed it the inverted FPGA clock), read data driven tAC after the
// edge following the READ and held tOH after the next one. Only the words that are used are kept.
module sdram_model #(parameter real T_AC = 6.0, parameter real T_OH = 2.5) (
	input wire clk,
	input wire [12:0] a,
	input wire [1:0] ba,
	inout wire [15:0] dq,
	input wire nras, ncas, nwe,
	input wire [1:0] dqm
);
reg [15:0] mem [0:65535];          // word index = { ba, row[4:0], col } folded: enough for the tests
reg [12:0] row [0:3];
reg [15:0] dq_o = 16'd0;
reg dq_oe = 1'b0;
assign dq = dq_oe ? dq_o : 16'bz;
integer i;
initial for (i = 0; i < 65536; i = i + 1) mem[i] = 16'h0000;
function [15:0] idx(input [1:0] b, input [12:0] r, input [8:0] c);
	idx = { b, r[4:0], c };
endfunction
reg [15:0] rd_idx;
always @(posedge clk) begin
	case ({ nras, ncas, nwe })
	3'b011: row[ba] <= a;                                    // ACTIVE
	3'b100: begin                                            // WRITE
		if (!dqm[0]) mem[idx(ba, row[ba], a[8:0])][7:0] <= dq[7:0];
		if (!dqm[1]) mem[idx(ba, row[ba], a[8:0])][15:8] <= dq[15:8];
	end
	3'b101: begin                                            // READ: CL2
		rd_idx = idx(ba, row[ba], a[8:0]);
		fork begin
			@(posedge clk); #(T_AC) begin dq_o <= mem[rd_idx]; dq_oe <= 1'b1; end
			@(posedge clk); #(T_OH) dq_oe <= 1'b0;
		end join_none
	end
	default: ;
	endcase
end
endmodule
