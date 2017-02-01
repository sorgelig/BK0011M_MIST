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

module data_io
(
	input             clk_sys,

	input             SPI_SCK,
	input             SPI_SS2,
	input             SPI_DI,

	output reg        ioctl_download = 0, // signal indicating an active download
	output reg  [7:0] ioctl_index,        // menu index used to upload the file
	output            ioctl_we,
	output reg [24:0] ioctl_addr,
	output reg [15:0] ioctl_dout
);

assign     ioctl_we = (wrx[1] | wrx[2]);
reg        rclk = 0;
reg  [2:0] wrx;
always@(posedge clk_sys) wrx <= {wrx[1:0], rclk};

localparam UIO_FILE_TX      = 8'h53;
localparam UIO_FILE_TX_DAT  = 8'h54;
localparam UIO_FILE_INDEX   = 8'h55;

always@(posedge SPI_SCK, posedge SPI_SS2) begin
	reg  [6:0] sbuf;
	reg  [7:0] cmd;
	reg  [4:0] cnt;
	reg [24:0] addr;
	reg  [7:0] data;
	reg        next = 0;

	if(SPI_SS2) cnt <= 0;
	else begin
		rclk <= 0;
		next <= 0;

		// don't shift in last bit. It is evaluated directly
		// when writing to ram
		if(cnt != 15) sbuf <= {sbuf[5:0], SPI_DI};

		// increase target address after write
		if(next) addr <= addr + 1'd1;

		// count 0-7 8-15 8-15 ... 
		if(cnt < 15) cnt <= cnt + 1'd1;
			else      cnt <= 8;

		// finished command byte
      if(cnt == 7) cmd <= {sbuf, SPI_DI};

		// prepare/end transmission
		if((cmd == UIO_FILE_TX) && (cnt == 15)) begin
			// prepare 
			if(SPI_DI) begin
				case(ioctl_index)
							0: addr <= 25'h0E0000;
							1: addr <= 25'h100000;
					default: addr <= 25'h120000;
				endcase
				ioctl_download <= 1;
			end else begin
				ioctl_download <= 0;
				ioctl_addr <= {addr[24:1] + 1'b1, 1'b0};
			end
		end

		// command 0x54: UIO_FILE_TX
		if((cmd == UIO_FILE_TX_DAT) && (cnt == 15)) begin

			next <= 1;

			if(addr[0]) begin
				ioctl_dout <= {sbuf, SPI_DI, data};
				ioctl_addr <= {addr[24:1], 1'b0};
				rclk       <= 1;
			end else begin
				data       <= {sbuf, SPI_DI};
			end
		end

      // expose file (menu) index
      if((cmd == UIO_FILE_INDEX) && (cnt == 15)) ioctl_index <= {sbuf, SPI_DI};
	end
end

endmodule
