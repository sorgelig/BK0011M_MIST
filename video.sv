`timescale 1ns / 1ps

module video(
	input         clk_pix, // Video clock (24 MHz)
	input			  clk_ram, // Video ram clock (>50 MHz)

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

	input	 [14:0] cache_addr,    // 2 screens with 16KB each.
	input	 [15:0] cache_data,
	input	  [1:0] cache_wtbt,
	input			  cache_we,      // write strobe
	
	// registers
	input			  wb_clk,
	input	 [15:0] wb_adr,
	input	 [15:0] wb_dat_i,
   output [15:0] wb_dat_o,
	input			  wb_cyc,
	input	  		  wb_we,
	input	  [1:0] wb_sel,
	input			  wb_stb,
	output		  wb_ack,
	output        wb_irq2,
	input         sys_init
);

`define HPOS 9'd18
`define VPOS 9'd36
`define VSYNC 9'd308

reg clk_12;
always @(posedge clk_pix) clk_12 <= !clk_12;

assign wb_irq2 = irq2 && !reg662[14];
reg irq2 = 1'b0;

dpram ram(
	.wraddress(cache_addr[14:1]),
	.byteena_a(cache_wtbt),
	.clock(clk_ram),
	.data(cache_data),
	.wren(cache_we),

	.rdaddress({screen_bank, addr}),
	.q(data)
);

reg  [9:0] hc;
wire [8:0] hcpic = hc[9:1] - `HPOS;
reg  [8:0] vc;
wire [8:0] vcpic = vc - `VPOS + roll;
reg  [7:0] roll;
reg  [8:0] vislines = 9'd256;

always @(posedge clk_12) begin
	if(hc == 767) begin 
		hc <=0;
		if (vc == 311) begin 
			vc <= 9'd0;
			roll <= roll_screen;
			vislines <= full_screen ? 9'd256 : 9'd64;
			irq2 <= 1'b0;
		end else begin 
			vc <= vc + 1'd1;
			if (vc == (`VSYNC - 9'd21)) irq2 <= 1'b1;
		end
	end else hc <= hc + 1'd1;
end

wire HBlank = !((hc[9:1] >= `HPOS) && (hc[9:1] < (`HPOS+9'd256)));
wire HSync  = (hc[9:1] >= 9'd312);

wire VBlank = !((vc >= `VPOS) && (vc < (`VPOS + vislines)));
wire VSync  = (vc >= `VSYNC);

wire [15:0] data;
wire [12:0] addr = (!HBlank && !VBlank) ? {vcpic[7:0],hcpic[7:3]} : 13'b0;

wire  [1:0] dotc = dots[1:0];
reg  [15:0] dots;
reg  viden;
reg  dotm = 1'b0;

always @(negedge clk_12) begin
	dotm  <= !dotm;
	dots  <= (data >> {hcpic[2:0], 1'b0});
	viden <= !HBlank && !VBlank;
end

wire [15:0] palettes[16] = '{
	16'h9420, 16'h9BD0, 16'hD640, 16'hB260,
	16'hFD60, 16'hFFF0, 16'h9810, 16'hBA30,
	16'hDC50, 16'h1350, 16'h8AC0, 16'h96B0,
	16'h6920, 16'hF6B0, 16'hFB20, 16'hF620
};
wire [15:0] comp = palettes[reg662[11:8]] >> {dotc[0],dotc[1], 2'b00};

wire Rh = viden && (color ? comp[3] : dotc[dotm]);
wire Rl = viden && (color ? comp[0] : dotc[dotm]);
wire Gh = viden && (color ? comp[1] : dotc[dotm]);
wire Bh = viden && (color ? comp[2] : dotc[dotm]);
wire Gl = Gh;
wire Bl = Bh;

assign VGA_HS     = scandoubler_disable ? ~(HSync ^ VSync) : ~sd_hs;
assign VGA_VS     = scandoubler_disable ? 1'b1 : ~sd_vs;
wire [5:0] VGA_Rx = scandoubler_disable ? {Rh, Rh, Rl, Rl, Rl, Rl} : {sd_r, sd_r[1:0]};
wire [5:0] VGA_Gx = scandoubler_disable ? {Gh, Gh, Gl, Gl, Gl, Gl} : {sd_g, sd_g[1:0]};
wire [5:0] VGA_Bx = scandoubler_disable ? {Bh, Bh, Bl, Bl, Bl, Bl} : {sd_b, sd_b[1:0]};

wire sd_hs, sd_vs;
wire [3:0] sd_r;
wire [3:0] sd_g;
wire [3:0] sd_b;

scandoubler scandoubler(
	.clk_x2(clk_pix),
	.scanlines(2'b00),
	    
	.hs_in(HSync),
	.vs_in(VSync),
	.r_in({Rh,Rh,Rl,Rl}),
	.g_in({Gh,Gh,Gl,Gl}),
	.b_in({Bh,Bh,Bl,Bl}),

	.hs_out(sd_hs),
	.vs_out(sd_vs),
	.r_out(sd_r),
	.g_out(sd_g),
	.b_out(sd_b)
);

osd #(-10'd36, 10'd0, 3'd4) osd(
	.*,
	.clk_pix(scandoubler_disable ? clk_12 : clk_pix),
	.OSD_VS(scandoubler_disable ? ~VSync : ~sd_vs),
	.OSD_HS(scandoubler_disable ? ~HSync : ~sd_hs)
);

///////////////////////////////////////////////////////////////////////////////////////

wire  [1:0] ena;
reg   [1:0] ack;
reg  [15:0] reg664  = 16'o1330;
reg  [15:0] reg662m = 16'o40000;
wire [15:0] reg662  = bk0010 ? 16'o40000 : reg662m;
wire screen_bank = reg662[15];

reg [15:0] data_o;
assign wb_dat_o = (valid && !wb_we) ? data_o : 16'd0;

wire sel662 = wb_cyc && (wb_adr[15:1] == (16'o177662 >> 1)) && wb_we && !bk0010;
wire stb662 = wb_stb && sel662;

wire sel664 = wb_cyc && (wb_adr[15:1] == (16'o177664 >> 1));
wire stb664 = wb_stb && sel664;

wire valid  = sel664 || sel662;

wire       full_screen = reg664[9];
wire [7:0] roll_screen = (reg664[7:0] - 8'o330);

assign wb_ack = wb_stb & valid & ack[1];
always @ (posedge wb_clk) begin
	ack[0] <= wb_stb & valid;
	ack[1] <= wb_cyc & ack[0];
end

always @(posedge stb664) begin
	if(wb_we) begin 
		if(wb_sel[1])   reg664[9] <= wb_dat_i[9];
		if(wb_sel[0]) reg664[7:0] <= wb_dat_i[7:0];
	end else data_o <= reg664;
end

always @(posedge stb662) begin
	if(wb_sel[1]) reg662m <= wb_dat_i;
end

endmodule
