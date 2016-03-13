`timescale 1ns / 1ps

module video(
	input         clk_pix, // Video clock (24 MHz)
	input         clk_ram, // Video ram clock (>50 MHz)

	input         color,
	input   [1:0] screen_write,
	input         bk0010,

	input         SPI_SCK,
	input         SPI_SS3,
	input         SPI_DI,

	// Video outputs
	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_VS,
	output        VGA_HS,

	input         scandoubler_disable,

	input  [14:0] cache_addr,    // 2 screens with 16KB each.
	input  [15:0] cache_data,
	input   [1:0] cache_wtbt,
	input         cache_we,      // write strobe
	
	// registers
	input         clk_bus,

	input  [15:0] bus_din,
	output [15:0] bus_dout,
	input  [15:0] bus_addr,

	input         bus_reset,
	input         bus_sync,
	input         bus_we,
	input   [1:0] bus_wtbt,
	input         bus_stb,
	output        bus_ack,

	output        irq2
);

reg clk_12;
always @(posedge clk_pix) clk_12 <= !clk_12;

assign irq2 = irq && !reg662[14];
reg irq = 1'b0;

dpram ram(
	.wraddress(cache_addr[14:1]),
	.byteena_a(cache_wtbt),
	.clock(clk_ram),
	.data(cache_data),
	.wren(cache_we),

	.rdaddress({screen_bank, vaddr}),
	.q(data)
);

wire [15:0] data;
wire [12:0] vaddr = {vc[7:0] + roll, hc[8:4]};

reg  [9:0] hc;
reg  [8:0] vc;
reg  [7:0] roll;

reg  [2:0] blank_mask;
reg  HSync;
reg  VSync;
wire CSync = HSync ^ VSync;

always @(posedge clk_12) begin
	if(hc == 767) begin 
		hc <=0;
		if (vc == 311) begin 
			vc <= 9'd0;
			roll <= roll_screen;
			blank_mask <= full_screen ? 3'b100 : 3'b111;
			irq <= 0;
		end else begin
			vc <= vc + 1'd1;

			if(vc == 268) VSync  <= 1;
			if(vc == 276) VSync  <= 0;
		end
	end else hc <= hc + 1'd1;

	if(hc == 593) HSync  <= 1;
	if(hc == 649) HSync  <= 0;

	// SECAM has 312.5 lines per field, hence correction for half line.
	if((vc == 256) && (hc == (649-384))) irq <= 1;
end

wire  [1:0] dotc = dots[1:0];
reg  [15:0] dots;
reg         dotm;

always @(negedge clk_12) begin
	dotm <= hc[0];
	if(!hc[0]) begin
		dots <= {2'b00, dots[15:2]};
		if(!hc[9] && !(vc[8:6] & blank_mask) && !hc[3:1]) dots <= data;
	end
end

wire [15:0] palettes[16] = '{
	16'h9420, 16'h9BD0, 16'hD640, 16'hB260,
	16'hFD60, 16'hFFF0, 16'h9810, 16'hBA30,
	16'hDC50, 16'h1350, 16'h8AC0, 16'h96B0,
	16'h6920, 16'hF6B0, 16'hFB20, 16'hF620
};
wire [15:0] comp = palettes[reg662[11:8]] >> {dotc[0],dotc[1], 2'b00};

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

scandoubler scandoubler(
	.*,
	.clk_x2(clk_pix),
	.scanlines(2'b00),

	.hs_in(HSync),
	.vs_in(VSync),
	.r_in(R_out),
	.g_in(G_out),
	.b_in(B_out)
);

assign {VGA_HS,  VGA_VS,  VGA_R, VGA_G, VGA_B} = scandoubler_disable ? 
       {~CSync,  1'b1,    R_out, G_out, B_out}: 
       {~hs_out, ~vs_out, r_out, g_out, b_out};

///////////////////////////////////////////////////////////////////////////////////////

wire  [1:0] ena;
reg         ack;
reg  [15:0] reg664  = 16'o1330;
reg  [15:0] reg662m = 16'o40000;
wire [15:0] reg662  = bk0010 ? 16'o40000 : reg662m;
wire screen_bank = reg662[15];

reg [15:0] data_o;
assign bus_dout = valid ? data_o : 16'd0;

wire sel662 = bus_sync && (bus_addr[15:1] == (16'o177662 >> 1)) && bus_we && !bk0010;
wire stb662 = bus_stb && sel662;

wire sel664 = bus_sync && (bus_addr[15:1] == (16'o177664 >> 1));
wire stb664 = bus_stb && sel664;

wire valid  = sel664 || sel662;

wire       full_screen = reg664[9];
wire [7:0] roll_screen = (reg664[7:0] - 8'o330);

assign bus_ack = bus_stb & valid & ack;
always @ (posedge clk_bus) ack <= bus_stb;

always @(posedge stb664) begin
	if(bus_we) begin 
		if(bus_wtbt[1])   reg664[9] <= bus_din[9];
		if(bus_wtbt[0]) reg664[7:0] <= bus_din[7:0];
	end else data_o <= reg664;
end

always @(posedge stb662) begin
	if(bus_wtbt[1]) reg662m <= bus_din;
end

endmodule
