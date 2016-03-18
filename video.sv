`timescale 1ns / 1ps

module video
(
	input         clk_pix, // Video clock (24 MHz)
	input         clk_ram, // Video ram clock (>50 MHz)

	// Misc. signals
	input         color,
	input   [1:0] screen_write,
	input         bk0010,
	input         color_switch,
	input         mode,

	// OSD bus
	input         SPI_SCK,
	input         SPI_SS3,
	input         SPI_DI,

	// Video outputs
	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_VS,
	output        VGA_HS,

	// CPU bus
	input         clk_bus,
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

reg clk_12;
always @(posedge clk_pix) clk_12 <= !clk_12;

assign irq2 = irq & irq_en;
reg irq = 1'b0;

dpram ram
(
	.wraddress({screen_write[1], bus_addr[13:1]}),
	.byteena_a(bus_wtbt),
	.clock(clk_ram),
	.data(bus_din),
	.wren(bus_we & bus_sync & bus_stb & (screen_write[1] | screen_write[0])),

	.rdaddress({screen_bank, vcr, hc[8:4]}),
	.q(vdata)
);

wire[15:0] vdata;

reg  [9:0] hc;
reg  [8:0] vc;
reg  [7:0] vcr;

reg  [2:0] blank_mask;
reg  HSync;
reg  VSync;
wire CSync = HSync ^ VSync;

always @(posedge clk_12) begin
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

wire  [1:0] dotc = dots[1:0];
reg  [15:0] dots;
reg         dotm;

always @(negedge clk_12) begin
	dotm <= hc[0];
	if(!hc[0]) begin
		dots <= {2'b00, dots[15:2]};
		if(!hc[9] && !(vc[8:6] & {1'b1, {2{~full_screen}}}) && !hc[3:1]) dots <= vdata;
	end
end

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

osd #(3'd4) osd
(
	.*,
	.clk_pix(clk_12),
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
	.clk_x2(clk_pix),
	.scanlines(2'b00),

	.hs_in(HSync),
	.vs_in(VSync),
	.r_in(R_out),
	.g_in(G_out),
	.b_in(B_out)
);

assign {VGA_HS,  VGA_VS,  VGA_R, VGA_G, VGA_B} = mode ? 
       {~CSync,  1'b1,    R_out, G_out, B_out}: 
       {~hs_out, ~vs_out, r_out, g_out, b_out};

///////////////////////////////////////////////////////////////////////////////////////

reg  [15:0] reg664      = 16'o001330;
reg  [15:0] reg662      = 16'o040000;
wire  [3:0] pal         = reg662[11:8];
wire        screen_bank = ~bk0010 &  reg662[15];
wire        irq_en      = ~bk0010 & ~reg662[14];
wire        full_screen = reg664[9];
wire  [7:0] scroll      = reg664[7:0];

assign bus_dout = sel664 ? reg664 : 16'd0;
assign bus_ack  = bus_stb & (sel664 | sel662);

wire sel662 = bus_sync && (bus_addr[15:1] == (16'o177662 >> 1)) && bus_we && !bk0010;
wire stb662 = bus_stb  && sel662;
wire sel664 = bus_sync && (bus_addr[15:1] == (16'o177664 >> 1));
wire stb664 = bus_stb  && sel664 && bus_we;

always @(posedge stb664) {reg664[9], reg664[7:0]} <= {bus_din[9], bus_din[7:0]};
always @(posedge stb662) reg662[15:14] <= bus_din[15:14];

wire stb662c = stb662 | color_switch;
always @(posedge stb662c) begin
	if(sel662) reg662[11:8] <= bus_din[11:8];
		else reg662[11:8] <= reg662[11:8] + 1'd1;
end

endmodule
