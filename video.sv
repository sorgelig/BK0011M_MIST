`timescale 1ns / 1ps

module video
(
	input         reset,

	input         clk_sys,
	input         ce_12mp,
	input         ce_12mn,

	// Misc. signals
	input         bk0010,
	input         color_switch,
	input         bw_switch,
	input         scandoubler_disable,
	input         ypbpr,

	// OSD bus
	input         SPI_SCK,
	input         SPI_SS3,
	input         SPI_DI,

	// Video signals
	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_VS,
	output        VGA_HS,
	output [13:0] vram_addr,
	input  [15:0] vram_data,

	// CPU bus
	input  [15:0] bus_din,
	output [15:0] bus_dout,
	input  [15:0] bus_addr,
	input         bus_sync,
	input         bus_we,
	input   [1:0] bus_wtbt,
	input         bus_stb,
	output        bus_ack,
	output        irq2
);

assign irq2 = irq & irq_en;
reg irq = 1'b0;

assign vram_addr = {screen_bank, vcr, hc[8:4]};

reg  [9:0] hc;
reg  [8:0] vc;
reg  [7:0] vcr;

reg  [2:0] blank_mask;
reg  HSync;
reg  VSync;

always @(posedge clk_sys) begin
	if(ce_12mp) begin
		hc <= hc + 1'd1;
		if(hc == 767) begin 
			hc <=0;

			vcr <= vcr + 1'd1;
			if(vc == 279) vcr <= scroll;

			vc <= vc + 1'd1;
			if (vc == 319) vc <= 9'd0;
		end

		if(hc == 593) begin
			HSync <= 1;
			if(vc == 276) VSync <= 1;
			if(vc == 280) VSync <= 0;
		end

		if(hc == 649) begin
			HSync <= 0;
			if(vc == 256) irq <= 1;
			if(vc == 000) irq <= 0;
		end
	end

	if(ce_12mn) begin
		dotm <= hc[0];
		if(!hc[0]) begin
			dots <= {2'b00, dots[15:2]};
			if(!hc[9] && !(vc[8:6] & {1'b1, {2{~full_screen}}}) && !hc[3:1]) dots <= vram_data;
		end
	end
end

wire  [1:0] dotc = dots[1:0];
reg  [15:0] dots;
reg         dotm;

wire [15:0] palettes[16] = '{
	16'h9420, 16'h9BD0, 16'hD640, 16'hB260,
	16'hFD60, 16'hFFF0, 16'h9810, 16'hBA30,
	16'hDC50, 16'h1350, 16'h8AC0, 16'h96B0,
	16'h6920, 16'hF6B0, 16'hFB20, 16'hF620
};
wire [15:0] comp = palettes[pal] >> {dotc[0],dotc[1], 2'b00};

wire [1:0] R;
wire G, B;
assign {R[1], B, G, R[0]} = color ? comp[3:0] : {4{dotc[dotm]}};

wire [5:0] R_out;
wire [5:0] G_out;
wire [5:0] B_out;

osd #(10'd0, 10'd0, 3'd4) osd
(
	.*,
	.ce_pix(ce_12mp),
	.R_in({3{R}}),
	.G_in({6{G}}),
	.B_in({6{B}})
);

wire hs_out, vs_out;
wire [5:0] r_out;
wire [5:0] g_out;
wire [5:0] b_out;

scandoubler scandoubler
(
	.*,
	.ce_x2(ce_12mp | ce_12mn),
	.ce_x1(ce_12mp),
	.scanlines(2'b00),

	.hs_in(HSync),
	.vs_in(VSync),
	.r_in(R_out),
	.g_in(G_out),
	.b_in(B_out)
);

video_mixer video_mixer
(
	.*,
	.ypbpr_full(1),

	.r_i({R_out, R_out[5:4]}),
	.g_i({G_out, G_out[5:4]}),
	.b_i({B_out, B_out[5:4]}),
	.hsync_i(HSync),
	.vsync_i(VSync),

	.r_p({r_out, r_out[5:4]}),
	.g_p({g_out, g_out[5:4]}),
	.b_p({b_out, b_out[5:4]}),
	.hsync_p(hs_out),
	.vsync_p(vs_out)
);

///////////////////////////////////////////////////////////////////////////////////////

reg  [15:0] reg664      = 'o001330;
reg  [15:0] reg662      = 'o045400;
wire  [3:0] pal         = reg662[11:8];
reg         color       = 1;
wire        screen_bank = ~bk0010 &  reg662[15];
wire        irq_en      = ~bk0010 & ~reg662[14];
wire        full_screen = reg664[9];
wire  [7:0] scroll      = reg664[7:0];

assign bus_dout = sel664 ? reg664 : 16'd0;
assign bus_ack  = bus_stb & (sel664 | sel662);

wire sel662  = bus_sync && (bus_addr[15:1] == (16'o177662 >> 1)) && bus_we && !bk0010;
wire sel664  = bus_sync && (bus_addr[15:1] == (16'o177664 >> 1));

always @(posedge clk_sys) begin
	reg old_stb, old_cswitch, old_bwswitch;
	{old_stb, old_cswitch, old_bwswitch} <= {bus_stb, color_switch, bw_switch};

	if(~old_stb & bus_stb) begin
		if(sel664 & bus_we) {reg664[9], reg664[7:0]} <= {bus_din[9], bus_din[7:0]};
		if(sel662) reg662[15:8] <= bus_din[15:8];
	end

	if(~old_bwswitch & bw_switch) color <= ~color;
	if(~old_cswitch & color_switch & color) reg662[11:8] <= reg662[11:8] + 1'd1;
	if(reset) reg662 <= bk0010 ? 16'o045400 : 16'o047400;
end

endmodule
