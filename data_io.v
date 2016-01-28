//
// data_io.v
//
// io controller writable ram for the MiST board
// http://code.google.com/p/mist-board/
//
// ZX Spectrum adapted version
//
// Copyright (c) 2015 Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module data_io (
	// io controller spi interface
	input         sck,
	input         ss,
	input         sdi,

	output        downloading,   // signal indicating an active download
	output [24:0] size,          // number of bytes in input buffer
   output  [4:0] index,         // menu index used to upload the file
	 
	// external ram interface
	input         clk,
	output        wr,
	output [24:0] a,
	output [15:0] d
);

assign downloading = downloading_reg;
assign d     = data;
assign a     = {write_a[24:1], 1'b0};
assign size  = a - 25'hA0000;
assign index = idx;
assign wr = (wrx[0] | wrx[1]);

// *********************************************************************************
// spi client
// *********************************************************************************

// this core supports only the display related OSD commands
// of the minimig
reg [6:0]  sbuf;
reg [7:0]  cmd;
reg [15:0] data;
reg [4:0]  cnt;
reg [4:0]  idx;
reg [1:0]  wrx;

reg [24:0] addr    = 25'hA0000;
reg [24:0] write_a = 25'hA0000;
reg rclk = 1'b0;
reg next = 1'b0;

localparam UIO_FILE_TX      = 8'h53;
localparam UIO_FILE_TX_DAT  = 8'h54;
localparam UIO_FILE_INDEX   = 8'h55;

reg downloading_reg = 1'b0;

// data_io has its own SPI interface to the io controller
always@(posedge sck, posedge ss) begin
	if(ss == 1'b1)
		cnt <= 5'd0;
	else begin
		rclk <= 1'b0;
		next <= 1'b0;

		// don't shift in last bit. It is evaluated directly
		// when writing to ram
		if(cnt != 15)
			sbuf <= { sbuf[5:0], sdi};

		// increase target address after write
		if(next)
			addr <= addr + 25'd1;
	 
		// count 0-7 8-15 8-15 ... 
		if(cnt < 15) 	cnt <= cnt + 4'd1;
		else				cnt <= 4'd8;

		// finished command byte
      if(cnt == 7)
			cmd <= {sbuf, sdi};

		// prepare/end transmission
		if((cmd == UIO_FILE_TX) && (cnt == 15)) begin
			// prepare 
			if(sdi) begin
				addr <= (idx) ? 25'hA0000 : 25'h80000;
				downloading_reg <= 1'b1;
			end else begin
				downloading_reg <= 1'b0;
				write_a <= (addr + 25'd1);
			end
		end

		// command 0x54: UIO_FILE_TX
		if((cmd == UIO_FILE_TX_DAT) && (cnt == 15)) begin
			write_a <= addr;

			if(addr[0]) data[15:8] <= {sbuf, sdi};
				else data[7:0] <= {sbuf, sdi};

			if(addr[0]) rclk <= 1'b1; // strobe every second byte
			next <= 1'b1;
		end

      // expose file (menu) index
      if((cmd == UIO_FILE_INDEX) && (cnt == 15))
			idx <= {sbuf[3:0], sdi};
	end
end

reg old_rclk;
always@(posedge clk) begin
	old_rclk <= rclk;
	wrx[0] <= old_rclk && !rclk;
	wrx[1] <= wrx[0];
end

endmodule
