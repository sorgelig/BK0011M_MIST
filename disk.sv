
module disk_wb
(
	input         clk_ram,
	input         reset,

	input         SPI_SCK,
	input         SPI_SS2,
	input         SPI_DI,

	input			  wb_clk,
	input	 [15:0] wb_adr,
	input	 [15:0] wb_dat_i,
	input			  wb_cyc,
	input	  		  wb_we,
	input	  [1:0] wb_sel,
	input			  wb_stb,
	output		  wb_ack,

	output        dsk_copy,
	output        dsk_copy_virt,
	output [24:0] dsk_copy_addr,
	input  [15:0] dsk_copy_data_i,
	output [15:0] dsk_copy_data_o,
	output        dsk_copy_we,
	output        dsk_copy_rd,
	
	output [31:0] sd_lba,
	output reg    sd_rd,
	output reg    sd_wr,
   input         sd_ack,
	output        sd_conf,
	output        sd_sdhc,
	input   [7:0] sd_dout,
	input         sd_dout_strobe,
	output reg [7:0] sd_din,
	input         sd_din_strobe,
	input         sd_mounted
);

assign sd_conf = 1'b0;
assign sd_sdhc = 1'b1;
assign sd_lba = conf ? 0 : lba;

reg   [7:0] hdd_hdr[4:0];
wire [31:0] hdd_sig = {hdd_hdr[0],hdd_hdr[1],hdd_hdr[2],hdd_hdr[3]};
wire  [7:0] hdd_ver = hdd_hdr[4];

wire [31:0] hdr_out;
reg   [6:0] hdr_addr;
sector_b2d sector_hdr (
	.clock(clk_ram),
	.data(sd_dout),
	.wraddress(sd_addr),
	.wren(conf && sd_ack && sd_dout_strobe2 && sd_dout_strobe1),
	.rdaddress(hdr_addr),
	.q(hdr_out)
);

wire [15:0] bk_ram_out;
sector_b2w sector_rd (
	.clock(clk_ram),
	.data(sd_dout),
	.wraddress(sd_addr),
	.wren(!conf && sd_ack && sd_dout_strobe2 && sd_dout_strobe1),
	.rdaddress(bk_addr),
	.q(bk_ram_out)
);

reg  [15:0] bk_data_wr;
reg         bk_wr;
wire  [7:0] sd_ram_out;
sector_w2b sector_wr (
	.clock(clk_ram),
	.data(bk_data_wr),
	.wraddress(bk_addr),
	.wren(bk_wr),
	.rdaddress(sd_addr),
	.q(sd_ram_out)
);

// strobe delay
reg sd_dout_strobe1, sd_dout_strobe2;
always @(posedge clk_ram) begin
	sd_dout_strobe1 <= sd_dout_strobe;
	sd_dout_strobe2 <= sd_dout_strobe1;
end

always @(posedge sd_dout_strobe2) begin
	if(sd_ack) begin
		if(conf && (sd_addr < 5)) hdd_hdr[sd_addr] <= sd_dout;
	end
end

always @(posedge sd_din_strobe) begin
	if(sd_ack) begin
		sd_din <= sd_ram_out;
	end
end

reg [8:0] sd_addr;
wire      sd_strobe = sd_dout_strobe2 | sd_din_strobe;
always @(negedge sd_strobe) begin
	if(sd_ack) sd_addr <= sd_addr + 1'd1;
		else sd_addr <= 9'd0;
end

assign dsk_copy        = ioctl_download | processing;
assign dsk_copy_we     = ioctl_download ? ioctl_we   : copy_we;
assign dsk_copy_rd     = ioctl_download ? 1'b0       : copy_rd;
assign dsk_copy_addr   = ioctl_download ? ioctl_addr : copy_addr;
assign dsk_copy_data_o = ioctl_download ? ioctl_data : copy_data_o;
assign dsk_copy_virt   = ioctl_download ? 1'b0       : copy_virt;

wire        ioctl_download;
wire        ioctl_we;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_data;
wire        ioctl_index;
wire [24:0] ioctl_size;

data_io data_io
(
	.sck(SPI_SCK),
	.ss(SPI_SS2),
	.sdi(SPI_DI),

	.downloading(ioctl_download),
	.size(ioctl_size),
	.index(ioctl_index),

	.clk(wb_clk),
	.wr(ioctl_we),
	.a(ioctl_addr),
	.d(ioctl_data)
);

reg  [24:0] copy_addr;
reg  [15:0] copy_data_o;
reg         copy_virt;
reg         copy_we;
reg         copy_rd;
wire [15:0] copy_data_i = dsk_copy_data_i;

//Allow R/W for stop/start disk motor. No actions are performed.
wire sel130 = wb_cyc && (wb_adr[15:1] == (16'o177130 >> 1));

//LBA access. Main access for disk read and write.
wire sel132 = wb_we && wb_cyc && (wb_adr[15:1] == (16'o177132 >> 1));

//CHS access. Currently not supported and always returns error.
//Paramaters can be recalculated for LBA call, but none of apps 
//used CHS access with exception of specific floppy utilities.
wire sel134 = wb_we && wb_cyc && (wb_adr[15:1] == (16'o177134 >> 1));

wire stb132 = wb_stb && sel132;
wire stb134 = wb_stb && sel134;
wire valid  = sel130 | sel132 | sel134;

assign wb_ack = wb_stb & valid & ack[1];
always @ (posedge wb_clk) begin
	ack[0] <= wb_stb & valid;
	ack[1] <= wb_cyc & ack[0];
end

wire reg_access = stb132 | stb134;

reg  [7:0] state = 8'b0;
reg [15:0] rSP;
reg [15:0] rPSW;
//reg [15:0] rR3;
reg [15:0] rR2;
reg [15:0] rR1;
//reg [15:0] rR0;
reg [15:0] error;

reg  [7:0] bk_addr;
reg [15:0] total_size;
reg [15:0] part_size;
reg [31:0] lba;
reg [31:0] lbaro;

reg [31:0] hdd_start;
reg [31:0] hdd_end;
reg  [7:0] disk;

reg  conf       = 1'b0;
reg  io_busy    = 1'b0;
reg  mounted    = 1'b0;
reg  processing = 1'b0;
reg  [1:0] ack;

always @ (posedge wb_clk) begin
	reg  old_access, old_mounted;
	reg  [5:0] ack;

	old_access <= reg_access;
	if(!old_access && reg_access) begin 
		processing <= 1'b1;
		state      <= 8'b0;
		rSP        <= wb_dat_i;
		copy_rd    <= 1'b0;
		copy_we    <= 1'b0;
		copy_virt  <= 1'b1;
		bk_wr      <= 1'b0;
		sd_wr      <= 1'b0;
		sd_rd      <= 1'b0;
	end

	if(reset) begin
		processing <= 1'b0;
		io_busy    <= 1'b0;
		sd_wr      <= 1'b0;
		sd_rd      <= 1'b0;
		copy_rd    <= 1'b0;
		copy_we    <= 1'b0;
	end
	
	ack <= {sd_ack, ack[5:1]};

	if(ack[0] && !ack[1]) begin
		if(conf) begin
			mounted <= ((hdd_sig == "BKHD") && (hdd_ver == 8'd1));
			conf    <= 1'b0;
		end
		io_busy <= 1'b0;
	end

	if(!ack[0] && ack[1]) begin
		sd_wr <= 1'b0;
		sd_rd <= 1'b0;
	end

	if(processing) begin
		case(state)
			0: begin
					copy_addr <= rSP+16'd6;
					state     <= state + 1'd1;
				end
			1: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			2: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			3: begin
					//rR3       <= copy_data_i;
					copy_rd   <= 1'b0;
					copy_addr <= copy_data_i + 16'o34;
					state     <= state + 1'd1;
				end
			4: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			5: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			6: begin
					disk      <= copy_data_i[7:0];
					hdr_addr  <= 7'd2 + copy_data_i[5:0];
					copy_addr <= rSP;
					copy_rd   <= 1'b0;
					state     <= state + 1'd1;
				end
			7: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			8: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			9: begin
					//rR0       <= copy_data_i;
					lbaro     <= copy_data_i;
					lba       <= hdr_out + copy_data_i;
					hdd_start <= hdr_out;
					copy_rd   <= 1'b0;
					copy_addr <= rSP+16'd2;
					state     <= state + 1'd1;
				end
			10: begin
					hdr_addr  <= hdr_addr + 7'd1;
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			11: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			12: begin
					rR1       <= copy_data_i;
					copy_rd   <= 1'b0;
					copy_addr <= rSP+16'd4;
					state     <= state + 1'd1;
				end
			13: begin
					hdd_end   <= hdr_out;
					total_size<= rR1[15] ? (~rR1)+16'd1 : rR1;
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			14: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			15: begin
					rR2       <= copy_data_i;
					copy_rd   <= 1'b0;
					copy_addr <= rSP+16'd8;
					state     <= state + 1'd1;
				end
			16: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			17: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			18: begin
					rPSW      <= copy_data_i;
					copy_rd   <= 1'b0;
					copy_addr <= 16'o52;
					state     <= state + 1'd1;
				end
			19: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			20: begin
					copy_rd   <= 1'b1;
					state     <= state + 1'd1;
				end
			21: begin
					error     <= copy_data_i;
					copy_rd   <= 1'b0;
					state     <= state + 1'd1;
				end
			22: begin
					if(disk) begin
					   //VHD access
						if((wb_adr != 16'o177132) || !mounted || !hdd_end || !hdd_start) begin
							error[7:0] <= 8'd6;
							rPSW[0]    <= 1'b1;
							state      <= 100;
						end else if(!total_size || rR2[0]) begin
							error[7:0] <= 8'd10;
							rPSW[0]    <= 1'b1;
							state      <= 100;
						end else if((lba+((total_size+255) >> 8)) > hdd_end) begin
							error[7:0] <= 8'd5;
							rPSW[0]    <= 1'b1;
							state      <= 100;
						end else 
							if(rR1[15]) state <= 8'd70; // write
									else  state <= 8'd50; // read
					end else begin
					   //DSK access
						if((wb_adr != 16'o177132) || rR1[15] /*|| (ioctl_index != 4)*/ || !ioctl_size) begin
							error[7:0] <= 8'd6;
							rPSW[0]    <= 1'b1;
							state      <= 100;
						end else if(!total_size || rR2[0]) begin
							error[7:0] <= 8'd10;
							rPSW[0]    <= 1'b1;
							state      <= 100;
						end else if((lba+((total_size+255) >> 8)) > (ioctl_size >> 9)) begin
							error[7:0] <= 8'd5;
							rPSW[0]    <= 1'b1;
							state      <= 100;
						end else begin 
							lbaro <= (lbaro << 9) + 32'hA0000;
							state <= 30; // read
						end
					end
				end

			// Disk-A read
			30: begin
					if(total_size == 16'd0) begin
						error[7:0] <= 8'd0;
						rPSW[0]    <= 1'b0;
						state      <= 100;
					end else begin
						copy_addr  <= lbaro;
						copy_virt  <= 1'b0;
						copy_rd    <= 1'b0;
						copy_we    <= 1'b0;
						state      <= state + 1'd1;
					end;
				end
			31: begin
					copy_rd     <= 1'b1;
					state       <= state + 1'd1;
				end
			32: begin
					copy_rd     <= 1'b1;
					state       <= state + 1'd1;
				end
			33: begin
					copy_data_o <= copy_data_i;
					copy_rd     <= 1'b0;
					copy_addr   <= rR2;
					copy_virt   <= 1'b1;
					state       <= state + 1'd1;
				end
			34: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			35: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			36: begin
					copy_we     <= 1'b0;
					rR2         <= rR2 + 2'd2;
					lbaro       <= lbaro + 2'd2;
					total_size  <= total_size - 1'd1;
					state       <= 30;
				end

			// Disk read
			50: begin
					if(!io_busy) begin
						sd_rd    <= 1'b1;
						io_busy  <= 1'b1;
						part_size<= (total_size < 16'd256) ? total_size : 16'd256;
						state    <= state + 1'd1;
					end
				end
			51: state         <= state + 1'd1;
			52: begin
					if(!io_busy) begin
						bk_addr  <= 7'd0;
						total_size <= total_size - part_size;
						state    <= state + 1'd1;
					end
				end
			53: begin 
					copy_data_o <= bk_ram_out;
					copy_addr   <= rR2;
					copy_we     <= 1'b0;
					state       <= state + 1'd1;
				end
			54: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			55: state         <= state + 1'd1;
			56: begin
					copy_we     <= 1'b0;
					rR2         <= rR2 + 2'd2;
					bk_addr     <= bk_addr + 2'd1;
					part_size   <= part_size - 2'd1;
					state       <= state + 1'd1;
				end
			57: begin
					if(part_size != 0) state <= 53;
					else if(total_size != 0) begin 
						lba   <= lba + 1;
						state <= 50;
					end else begin
						error[7:0] <= 8'd0;
						rPSW[0]    <= 1'b0;
						state      <= 100;
					end
				end
				
			//Disk write
			70: begin
					if(!io_busy) begin
						bk_wr     <= 1'b0;
						bk_addr   <= 7'd0;
						part_size <= (total_size < 16'd256) ? total_size : 16'd256;
						state     <= state + 1'd1;
					end
				end
			71: begin
					total_size   <= total_size - part_size;
					state        <= state + 1'd1;
				end
			72: begin
					copy_addr    <= rR2;
					bk_wr        <= 1'b0;
					copy_rd      <= 1'b1;
					state        <= state + 1'd1;
				end
			73: state          <= state + 1'd1;
			74: begin
					bk_data_wr   <= copy_data_i;
					copy_rd      <= 1'b0;
					rR2          <= rR2 + 2'd2;
					part_size    <= part_size - 2'd1;
					state        <= state + 1'd1;
				end
			75: begin
					bk_wr        <= 1'b1;
					state        <= state + 1'd1;
				end
			76: begin
					bk_wr        <= 1'b0;
					state        <= state + 1'd1;
				end
			77: begin
					bk_addr      <= bk_addr + 2'd1;
					if(part_size != 0) state <= 72;
						else state<= state + 1'd1;
				end
			78: begin
					if(!io_busy) begin
						sd_wr     <= 1'b1;
						io_busy   <= 1'b1;
						state     <= state + 1'd1;
					end
				end
			79: begin
					if(!io_busy) begin
						if(total_size != 0) begin 
							lba    <= lba + 1;
							state  <= 70;
						end else begin
							error[7:0] <= 8'd0;
							rPSW[0]    <= 1'b0;
							state      <= 100;
						end
					end
				end

			// Finish. Post the exit code.
			100: begin
					copy_virt   <= 1'b1;
					copy_data_o <= error;
					copy_addr   <= 16'o52;
					copy_we     <= 1'b0;
					state       <= state + 1'd1;
				end
			101: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			102: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			103: begin
					copy_data_o <= rPSW;
					copy_addr   <= rSP+16'd8;
					copy_we     <= 1'b0;
					state       <= state + 1'd1;
				end
			104: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			105: begin
					copy_we     <= 1'b1;
					state       <= state + 1'd1;
				end
			106: begin
					copy_we     <= 1'b0;
					copy_rd     <= 1'b0;
					processing  <= 1'b0;
					state       <= state + 1'd1;
				end
		endcase
	end

	if(!io_busy) begin
		if(!old_mounted && sd_mounted) begin
			mounted  <= 1'b0;
			conf     <= 1'b1;
			sd_rd    <= 1'b1;
			io_busy  <= 1'b1;
		end
		old_mounted <= sd_mounted;
	end
end

endmodule
