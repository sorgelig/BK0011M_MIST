//
//	BK0011M/BK0010 memory implementation.
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

module memory_wb 
(
	inout  [15:0] SDRAM_DQ,
	output [12:0] SDRAM_A,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output  [1:0] SDRAM_BA,
	output        SDRAM_nCS,
	output        SDRAM_nWE,
	output        SDRAM_nRAS,
	output        SDRAM_nCAS,
	output        SDRAM_CKE,

	input         init,
	input         clk_ram,
	input         clk_037,
	input         bk0010,
	input         disk_rom,
	output  [7:0] start_addr,
	input         sysreg_sel,
	input  [15:0] ext_mode,
	input         cold_start,
	input         mode_start,

	input         clk_bus,

	input  [15:0] bus_din,
	output [15:0] bus_dout,
	input  [15:0] bus_addr,

	input         bus_sync,
	input         bus_we,
	input   [1:0] bus_wtbt,
	input         bus_stb,
	output        bus_ack,

	output  [1:0] screen_write,

	input         mem_copy,
	input         mem_copy_virt,
	input  [24:0] mem_copy_addr,
	input  [15:0] mem_copy_data_i,
	output [15:0] mem_copy_data_o,
	input         mem_copy_we,
	input         mem_copy_rd
);

sram ram
(
	.*,
	
	.clk_sdram(clk_ram),	

	.addr(ram_addr[24:1]),
	.dout(ram_o),
	.din (mem_copy ? mem_copy_data_i : bus_din),
	.wtbt(mem_copy ? 2'b11           : bus_wtbt),
	.we  (mem_copy ? copy_we         : bus_we & ram_stb),
	.rd  (mem_copy ? mem_copy_rd     : ~bus_we & ram_stb)
);

wire [15:0] ram_o;
assign mem_copy_data_o = ram_o;

//
// Memory map
//
`define RAM_P00    25'H00000 //
`define RAM_P01    25'H04000 //
`define RAM_P02    25'H08000 //
`define RAM_P03    25'H0C000 //
`define RAM_P04    25'H10000 //
`define RAM_P05    25'H14000 //
`define RAM_P06    25'H18000 //
`define RAM_P07    25'H1C000 //
                             //
`define RAM_EXT    25'H20000 // 768KB for expansions.
                             //
`define ROM_START  25'HE0000 // 
`define ROM_P10    25'HE0000 // BASIC11
`define ROM_P11    25'HE4000 // BASIC11 + BIOS11Ext
`define ROM_P12    25'HE8000 // (empty)
`define ROM_P13    25'HEC000 // Debugger (13;1C 100000G)
`define BIOS11     25'HF0000 //
`define DISKSTD    25'HF2000 // Default disk ROM
                             //
`define BIOS10     25'HF4000 //
`define BASIC10    25'HF6000 //
                             //
`define A16M_ROM   25'HFC000 // Optional. (required for A16M emulation)
`define SMK512_ROM 25'HFD000 // Optional. (required for SMK512 emulation)
                             //
`define MSTD_ROM   25'HFE000 // 
                             //
`define NOMEM     25'H100000 // End of memory / No memory


//SMK512 extension (used in BK0011M)

`define SMK_SYS_MODE   7
`define SMK_STD10_MODE 3
`define SMK_OZU10_MODE 5
`define SMK_ALL_MODE   1
`define SMK_STD11_MODE 6
`define SMK_OZU11_MODE 2
`define SMK_HLT10_MODE 4
`define SMK_HLT11_MODE 0

wire [24:0] smk512_page[4];
wire [24:0] smk512_7;
wire        smk512_0ro;

wire [24:0] smk512_base;
always @(ext_mode, bk0010) begin
	smk512_base   = `RAM_EXT + {ext_mode[11:8], 15'd0};
	
	case(ext_mode[6:4])

		//SMK_SYS_MODE
		default: begin
				smk512_page = '{
					bk0010 ? 25'H0 : `NOMEM,
					smk512_base | 25'H6000,
					smk512_base | 25'H0000,
					`SMK512_ROM
				};
				smk512_7 = `SMK512_ROM;
				smk512_0ro = 1'b0;
			end

		`SMK_STD10_MODE: begin
				smk512_page = '{
					bk0010 ? 25'H0 : `NOMEM,
					smk512_base | 25'H2000,
					smk512_base | 25'H4000,
					`SMK512_ROM
				};
				smk512_7 = smk512_base | 25'H7000;
				smk512_0ro = 1'b0;
			end

		`SMK_OZU10_MODE: begin
				smk512_page = '{
					smk512_base | 25'H0000,
					smk512_base | 25'H2000,
					smk512_base | 25'H4000,
					smk512_base | 25'H6000
				};
				smk512_7 = smk512_base | 25'H7000;
				smk512_0ro = 1'b0;
			end

		`SMK_ALL_MODE: begin
				smk512_page = '{
					smk512_base | 25'H4000,
					smk512_base | 25'H6000,
					smk512_base | 25'H0000,
					smk512_base | 25'H2000
				};
				smk512_7 = smk512_base | 25'H3000;
				smk512_0ro = 1'b0;
			end

		`SMK_STD11_MODE: begin
				smk512_page = '{
					25'H0,
					bk0010 ? `NOMEM : 25'H0,
					bk0010 ? `NOMEM : 25'H0,
					`SMK512_ROM
				};
				smk512_7 = smk512_base | 25'H7000;
				smk512_0ro = 1'b0;
			end

		`SMK_OZU11_MODE: begin
				smk512_page = '{
					25'H0,
					bk0010 ? `NOMEM : 25'H0,
					smk512_base | 25'H4000,
					smk512_base | 25'H6000
				};
				smk512_7 = smk512_base | 25'H7000;
				smk512_0ro = 1'b0;
			end

		`SMK_HLT10_MODE: begin
				smk512_page = '{
					smk512_base | 25'H0000,
					smk512_base | 25'H2000,
					smk512_base | 25'H4000,
					smk512_base | 25'H6000
				};
				smk512_7 = smk512_base | 25'H7000;
				smk512_0ro = 1'b1;
			end

		`SMK_HLT11_MODE: begin
				smk512_page = '{
					bk0010 ? `NOMEM : 25'H0,
					bk0010 ? `NOMEM : 25'H0,
					smk512_base | 25'H4000,
					smk512_base | 25'H6000
				};
				smk512_7 = smk512_base | 25'H7000;
				smk512_0ro = 1'b0;
			end
	endcase
end



//A16M extension (used in BK0010)

`define A16M_START_MODE 7
`define A16M_STD10_MODE 3
`define A16M_OZU10_MODE 5
`define A16M_BASIC_MODE 1
`define A16M_STD11_MODE 6
`define A16M_OZU11_MODE 2
`define A16M_OZUZZ_MODE 4
`define A16M_HLT11_MODE 0

wire [24:0] a16m_page[4];
wire        a16m_0ro;
wire        a16m_7en;
wire        a16m_7wr;
wire [24:0] a16m_empty;

always @(ext_mode, bk0010) begin
	//Bit3 is used only in BASIC mode.
	//It's not the same as in real A16M, but should be enough.
	a16m_empty = ext_mode[3] ? 25'H0 : `NOMEM;
	
	case(ext_mode[6:4])

		//A16M_START_MODE
		default: begin
				a16m_page = '{
					bk0010 ? 25'H0 : `NOMEM,
					`RAM_EXT + 25'H2000,
					`RAM_EXT + 25'H0000,
					`A16M_ROM
				};
				a16m_0ro = 1'b0;
				a16m_7en = 1'b1;
				a16m_7wr = 1'b0;
			end

		`A16M_STD10_MODE: begin
				a16m_page = '{
					bk0010 ? 25'H0 : `NOMEM,
					`RAM_EXT + 25'H2000,
					`RAM_EXT + 25'H0000,
					`A16M_ROM
				};
				a16m_0ro = 1'b0;
				a16m_7en = 1'b0;
				a16m_7wr = 1'b0;
			end

		`A16M_OZU10_MODE: begin
				a16m_page = '{
					`RAM_EXT + 25'H0000,
					`RAM_EXT + 25'H2000,
					bk0010 ? `NOMEM : 25'H0,
					`A16M_ROM
				};
				a16m_0ro = 1'b0;
				a16m_7en = 1'b0;
				a16m_7wr = 1'b0;
			end

		`A16M_BASIC_MODE: begin
				a16m_page = '{
					`RAM_EXT + 25'H0000,
					bk0010 ? a16m_empty : `NOMEM,
					bk0010 ? a16m_empty : `NOMEM,
					bk0010 ? a16m_empty : `NOMEM
				};
				a16m_0ro = 1'b1;
				a16m_7en = ext_mode[3];
				a16m_7wr = 1'b0;
			end

		`A16M_STD11_MODE: begin
				a16m_page = '{
					25'H0,
					bk0010 ? `NOMEM : 25'H0,
					bk0010 ? `NOMEM : 25'H0,
					`A16M_ROM
				};
				a16m_0ro = 1'b0;
				a16m_7en = 1'b0;
				a16m_7wr = 1'b0;
			end

		`A16M_OZU11_MODE: begin
				a16m_page = '{
					25'H0,
					bk0010 ? `NOMEM : 25'H0,
					`RAM_EXT + 25'H0000,
					`RAM_EXT + 25'H2000
				};
				a16m_0ro = 1'b0;
				a16m_7en = 1'b0;
				a16m_7wr = 1'b0;
			end

		`A16M_OZUZZ_MODE: begin
				a16m_page = '{
					`RAM_EXT + 25'H0000,
					`RAM_EXT + 25'H2000,
					bk0010 ? `NOMEM : 25'H0,
					`A16M_ROM
				};
				a16m_0ro = 1'b1;
				a16m_7en = 1'b0;
				a16m_7wr = 1'b0;
			end

		`A16M_HLT11_MODE: begin
				a16m_page = '{
					bk0010 ? `NOMEM  : 25'H0,
					bk0010 ? `NOMEM  : 25'H0,
					`RAM_EXT + 25'H0000,
					`RAM_EXT + 25'H2000
				};
				a16m_0ro = 1'b0;
				a16m_7en = 1'b0;
				a16m_7wr = 1'b1;
			end
	endcase
end

assign start_addr = (ext_rom && cold_start && mode_start) ? cold_addr  :
                       (ext_rom && mode_start && !bk0010) ? cold_addr  : // Every start is cold for SMK
                                                  bk0010  ? 8'b10000000: // Standard BK0010
                                                            8'b11000000; // Standard BK0011M

wire [7:0] cold_addr = bk0010 ? start_a16m : start_smk512;
wire       ext_rom   = disk_rom && cold_addr;

reg [7:0] start_a16m   = 8'd0;
reg [7:0] start_smk512 = 8'd0;
reg [4:0] page_avail = 5'b00010;
always @(posedge mem_copy_we) begin
	if(!mem_copy_virt && mem_copy) begin
		case({mem_copy_addr[24:14], 14'd0})
			`ROM_P10: page_avail[0] <= (page_avail[0] || mem_copy_data_i);
			`ROM_P11: page_avail[1] <= (page_avail[1] || mem_copy_data_i);
			`ROM_P12: page_avail[3] <= (page_avail[3] || mem_copy_data_i);
			`ROM_P13: page_avail[4] <= (page_avail[4] || mem_copy_data_i);
		endcase
		
		if(mem_copy_addr == (`A16M_ROM   + 25'HFCE)) start_a16m   <= mem_copy_data_i[15:8];
		if(mem_copy_addr == (`SMK512_ROM + 25'HFCE)) start_smk512 <= mem_copy_data_i[15:8];
	end
end

reg [15:0] page_reg;
wire sysreg_write = bus_stb & sysreg_sel & bus_we;
always @(posedge sysreg_write) if(bus_din[11] && bus_wtbt[1]) page_reg <= bus_din;

function [24:0] page2addr;
	input [2:0] value;
begin
	case (value)
		 3'b110: page2addr = `RAM_P00;
		 3'b000: page2addr = `RAM_P01;
		 3'b010: page2addr = `RAM_P02;
		 3'b011: page2addr = `RAM_P03;
		 3'b100: page2addr = `RAM_P04;
		 3'b001: page2addr = `RAM_P05;
		 3'b111: page2addr = `RAM_P06;
		default: page2addr = `RAM_P07;
   endcase
end
endfunction

wire [24:0] romp1 = (page_reg[0] & page_avail[0]) ? `ROM_P10 :
						  (page_reg[1] & page_avail[1]) ? `ROM_P11 :
						  (page_reg[3] & page_avail[3]) ? `ROM_P12 :
						  (page_reg[4] & page_avail[4]) ? `ROM_P13 : `NOMEM;

wire [15:0] addr = mem_copy ? mem_copy_addr[15:0] : bus_addr;

wire [24:0] map11s = ((addr[15:14] == 2'b00)  ? `RAM_P00 :
						    (addr[15:14] == 2'b01)  ? page2addr(page_reg[14:12])     :
						    (addr[15:13] == 3'b110) ? `BIOS11  :
						    (addr[15:13] == 3'b111) ? (disk_rom ? `DISKSTD : `MSTD_ROM) :
						    (page_reg  & 16'b11011) ? romp1    :
                                                page2addr(page_reg[10:8])) | addr[13:0];
wire [24:0] map11e = (addr[15:12] == 4'b1111)  ? (smk512_7 | addr[11:0]) :
                      smk512_page[addr[14:13]] ? (smk512_page[addr[14:13]] | addr[12:0]) : 25'H0;
wire [24:0] map11  = (addr[15] && ext_rom && map11e) ? map11e : map11s;

wire a16m_7 = (mem_copy ? mem_copy_we : bus_we) ? a16m_7wr : a16m_7en;
wire [24:0] map10de   = ((addr[15:12] == 4'b1111) && !a16m_7) ? `NOMEM : a16m_page[addr[14:13]];
wire [24:0] map10ds   = (addr[15:13] == 4'b101) ? `RAM_P02 : // two different pages because not aligned to 8kb
                        (addr[15:13] == 4'b110) ? `RAM_P03 : // ---/---
                        (addr[15:13] == 4'b111) ? `DISKSTD : 25'H0;
wire [24:0] map10d    = ext_rom ? map10de : map10ds;
wire [24:0] map10s[8] = '{`RAM_P00, `RAM_P00+25'H2000, `RAM_P05, `RAM_P05+25'H2000, `BIOS10, `BASIC10, `BASIC10+25'H2000, `BASIC10+25'H4000};
wire [24:0] map10     = ((addr[15] && disk_rom && map10d) ? map10d : map10s[addr[15:13]]) | addr[12:0];

wire [24:0] vaddr = bk0010 ? map10 : map11;
wire [24:0] ram_addr = (mem_copy && !mem_copy_virt) ? mem_copy_addr : vaddr;
wire ro = (vaddr >= `ROM_START) || (ext_rom && (addr[15:12] == 4'b1000) && (bk0010 ? a16m_0ro : smk512_0ro));
wire copy_we = mem_copy_we && (!mem_copy_virt || !ro);

wire [15:0] top_addr = ((ext_rom && !ext_mode[2]) || (disk_rom && !ext_rom)) ? 16'o177000 : 16'o177600;

assign screen_write[0] = ({ram_addr[24:14], 14'd0} == `RAM_P05);
assign screen_write[1] = ({ram_addr[24:14], 14'd0} == `RAM_P06);


///////////////////////////////////////////

wire is_ram  = ~ro & (bus_addr < 16'o177000);
wire is_rom  = ~is_ram & (bus_addr < top_addr) & (ram_addr < `NOMEM);
wire valid   =  is_ram | (is_rom & ~bus_we);
wire ram_stb =  bus_sync & valid & bus_stb;

assign bus_dout = (bus_sync & valid) ? ram_o : 16'd0;
assign bus_ack  = vp037_ack | ext_ack;

wire legacy_ram = (ram_addr < `RAM_EXT);

// VP1-037 contention
wire vp037_ack = TRPLY & ~RASEL;

wire dio = legacy_ram & valid & bus_stb;
reg PC90, RASEL, TRPLY;
always_latch if (RASEL) TRPLY = 1'b1; else if(~dio) TRPLY = 1'b0;

reg [2:0] PC;
always @(negedge clk_037) begin
	PC <= PC + 1'd1;
	if(~PC[0]) PC90 <= PC[1];
end

always @(posedge clk_037) begin
	if (PC90 & PC[1]) RASEL <= 0;
		else if (PC90 & ~PC[1] & PC[2]) RASEL <= bus_sync & ~vp037_ack & dio;
end

// Ext RAM or ROM ack
reg  ack;
wire ext_ack = ram_stb & !legacy_ram & ack;
always @(posedge clk_bus) ack <= bus_stb;

endmodule
