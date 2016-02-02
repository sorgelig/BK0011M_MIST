//
// sram.sv
//
// Static RAM controller implementation for slow bus (<10MHz) using SDRAM MT48LC16M16A2
// 
// Copyright (c) 2015 Sorgelig
//
// Some parts of SDRAM code used from project: 
// http://hamsterworks.co.nz/mediawiki/index.php/Simple_SDRAM_Controller
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License version 2 as published 
// by the Free Software Foundation
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sram 
(
	// interface to the MT48LC16M16 chip
	inout  wire [15:0] SDRAM_DQ,    // 16 bit bidirectional data bus
	output reg  [12:0] SDRAM_A,     // 13 bit multiplexed address bus
	output reg         SDRAM_DQML,  // two byte masks
	output reg         SDRAM_DQMH,  // 
	output reg  [1:0]  SDRAM_BA,    // two banks
	output wire        SDRAM_nCS,   // a single chip select
	output wire        SDRAM_nWE,   // write enable
	output wire        SDRAM_nRAS,  // row address select
	output wire        SDRAM_nCAS,  // columns address select
	output reg         SDRAM_CKE,   // clock enable

	// cpu/chipset interface
	input  wire        init,			// reset to initialize RAM
	input  wire        clk_sdram,		// sdram is accessed at 112MHz
	
	input  wire [23:0] addr,         // 24 bit address

	output wire [15:0] dout,			// data output to cpu
	input  wire [15:0] din,			   // data input from cpu
	input  wire [1:0]  wtbt,		   // mask byte for write
	input  wire        we,           // cpu requests write
	input  wire        rd            // cpu requests read
);

// no burst configured
localparam RASCAS_DELAY   = 3'd3;   // 3 cycles for 112MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2 for < 100MHz, 3 for >100MHz
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

parameter sdram_startup_cycles    = 14'd10100; // -- 100us, plus a little more, @ 100MHz
parameter cycles_per_refresh      = 14'd1524;  // (64000*100)/4196-1 Calc'd as  (64ms @ 100MHz)/ 4196 rose
parameter startup_refresh_max     = 14'b11111111111111;
reg  [13:0] startup_refresh_count = startup_refresh_max-sdram_startup_cycles;

localparam STATE_STARTUP     = 0;
localparam STATE_IDLE        = 1;
localparam STATE_IDLE_1      = 2;
localparam STATE_IDLE_2      = 3;
localparam STATE_IDLE_3      = 4;
localparam STATE_IDLE_4      = 5;
localparam STATE_IDLE_5      = 6;
localparam STATE_IDLE_6      = 7;
localparam STATE_OPEN_1      = 8;
localparam STATE_OPEN_2      = 9;
localparam STATE_WRITE_1     = 10;
localparam STATE_WRITE_2     = 11;
localparam STATE_WRITE_3     = 12;
localparam STATE_READ_1      = 13;
localparam STATE_READ_2      = 14;
localparam STATE_READ_3      = 15;
localparam STATE_READ_4      = 16;
localparam STATE_PRECHARGE   = 17;
localparam STATE_PRECHARGE_1 = 18;
localparam STATE_PRECHARGE_2 = 19;
localparam STATE_PRECHARGE_3 = 20;


reg [4:0] state = STATE_STARTUP;

// SDRAM commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0] command;
assign SDRAM_nCS  = command[3];
assign SDRAM_nRAS = command[2];
assign SDRAM_nCAS = command[1];
assign SDRAM_nWE  = command[0];

reg [23:0] save_addr = 24'd0;
reg [15:0] save_data = 16'd0;
reg [1:0]  save_wtbt = 2'b00;
reg save_we    = 1'b0;

reg got_transaction    = 1'b0;
reg ready_for_new      = 1'b0;

parameter data_ready_delay_high = CAS_LATENCY+1;
reg [data_ready_delay_high:0] data_ready_delay;

assign dout = save_data;

reg rd1,rd2;
reg we1,we2;

reg new_request = 1'b0;

assign SDRAM_DQ = save_we ? save_data : 16'bZZZZZZZZZZZZZZZZ;

always @(posedge clk_sdram) begin

	command   <= CMD_NOP;
	SDRAM_A   <= 13'b0000000000000;
	SDRAM_BA  <= 2'b00;
	
	startup_refresh_count  <= startup_refresh_count+14'b1;

	rd1 <= rd;
	rd2 <= rd1;
	
	we1 <= we;
	we2 <= we1;
	
	if(
		(rd1 && !rd2 && ((save_addr != addr) || (save_wtbt != 2'b11))) ||
		(we1 && !we2 && ((save_addr != addr) || (save_data != din) || (save_wtbt != wtbt)))
	) begin
		new_request <= 1'b1;
	end;

	if (ready_for_new && new_request) begin
		if(we) save_data <= din;
		save_addr        <= addr;
		save_we          <= we;
		save_wtbt        <= (we) ? wtbt : 2'b11;
		got_transaction  <= 1'b1;
		ready_for_new    <= 1'b0;
		new_request      <= 1'b0;
	end
	
   if (data_ready_delay[0] == 1'b1) begin
		if(!save_we) save_data <= SDRAM_DQ;
		ready_for_new <= 1'b1;
   end
	
   data_ready_delay <= {1'b0, data_ready_delay[data_ready_delay_high:1]};
	
	case(state) 
		STATE_STARTUP: begin
			save_we    <= 1'b0;
			SDRAM_CKE  <= 1'b1;
			SDRAM_DQML <= 1'b1;
			SDRAM_DQMH <= 1'b1;

			// All the commands during the startup are NOPS, except these
			if(startup_refresh_count == startup_refresh_max-31) begin
				// ensure all rows are closed
				command     <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;  // all banks
				SDRAM_BA    <= 2'b00;
			end else if (startup_refresh_count == startup_refresh_max-23) begin
				// these refreshes need to be at least tREF (66ns) apart
				command     <= CMD_AUTO_REFRESH;
			end else if (startup_refresh_count == startup_refresh_max-15) 
				command     <= CMD_AUTO_REFRESH;
			else if (startup_refresh_count == startup_refresh_max-7) begin
				// Now load the mode register
				command     <= CMD_LOAD_MODE;
				SDRAM_A     <= MODE;
			end

			if (startup_refresh_count == 1'b0) begin
				state           <= STATE_IDLE;
				ready_for_new   <= 1'b1;
				got_transaction <= 1'b0;
				startup_refresh_count <= 14'd2048 - cycles_per_refresh + 14'd1;
			end
		end
		
		STATE_IDLE_6: begin
				command  <= CMD_AUTO_REFRESH;
				state    <= STATE_IDLE_5;
			end
		
		STATE_IDLE_5: state <= STATE_IDLE_4;
		STATE_IDLE_4: state <= STATE_IDLE_3;
		STATE_IDLE_3: state <= STATE_IDLE_2;
		STATE_IDLE_2: state <= STATE_IDLE_1;
		STATE_IDLE_1: state <= STATE_IDLE;

		STATE_IDLE: begin
			if (got_transaction == 1'b1) begin
				state    <= STATE_OPEN_2;
				command  <= CMD_ACTIVE;
				SDRAM_A  <= save_addr[21:9];
				SDRAM_BA <= save_addr[23:22];
			end else state <= STATE_IDLE_6;

			SDRAM_DQML  <= 1'b1;
			SDRAM_DQMH  <= 1'b1;
		end
		STATE_OPEN_2: state <= STATE_OPEN_1;

		STATE_OPEN_1: begin 
			if(save_we == 1'b1) begin
				state      <= STATE_WRITE_1;
				SDRAM_DQML <= ~save_wtbt[0];
				SDRAM_DQMH <= ~save_wtbt[1];
			end else begin
				state      <= STATE_READ_1;
				SDRAM_DQ   <= 16'bZZZZZZZZZZZZZZZZ;
				SDRAM_DQML <= 1'b0;
				SDRAM_DQMH <= 1'b0;
			end
		end

		STATE_READ_1: begin
			got_transaction       <= 1'b0;

			state       <= STATE_READ_3;
			command     <= CMD_READ;
			SDRAM_A     <= {4'b0000, save_addr[8:0]}; 
			SDRAM_BA    <= save_addr[23:22];
			SDRAM_A[10] <= 1'b1;

			data_ready_delay[data_ready_delay_high] <= 1'b1;
		end

		STATE_READ_3: state <= STATE_READ_4;
		STATE_READ_4: state <= STATE_PRECHARGE;

		STATE_WRITE_1: begin
			got_transaction <= 1'b0;

			state       <= STATE_WRITE_2;
			command     <= CMD_WRITE;
			SDRAM_A     <= {4'b0000, save_addr[8:0]};
			SDRAM_BA    <= save_addr[23:22];
			SDRAM_A[10] <= 1'b1;
		end

		STATE_WRITE_2: begin
			state          <= STATE_PRECHARGE;
			save_we        <= 1'b0;
			ready_for_new  <= 1'b1;
		end

		STATE_PRECHARGE: begin
			state       <= STATE_PRECHARGE_2;
		end

		STATE_PRECHARGE_2: state <= STATE_PRECHARGE_1;
		STATE_PRECHARGE_1: state <= STATE_IDLE_6;

		default: begin 
			state                 <= STATE_STARTUP;
			ready_for_new         <= 1'b0;
			startup_refresh_count <= startup_refresh_max-sdram_startup_cycles;
		end
	endcase

	if (init == 1'b1) begin  // Sync reset
		state                 <= STATE_STARTUP;
		ready_for_new         <= 1'b0;
		startup_refresh_count <= startup_refresh_max-sdram_startup_cycles;
	end
end
endmodule
