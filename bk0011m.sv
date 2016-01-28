////////////////////////////////////////////////////////////////////////////////
//
//
//
// BK0011M for MIST board
// (C) 2016 Sorgelig
//
// This source file and all other files in this project is free software: 
// you can redistribute it and/or modify it under the terms of the 
// GNU General Public License version 2 unless explicitly specified in particular file.
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//
//
//
////////////////////////////////////////////////////////////////////////////////

`define 	DCLO_WIDTH_CLK			24   //  >5ms for 27MHz
`define	ACLO_DELAY_CLK			240  // >70ms for 27MHz

module cpu_reset
(
	input		clk,
	input		button,
	input		plock,
	output	dclo,
	output	aclo
);
localparam DCLO_COUNTER_WIDTH = log2(`DCLO_WIDTH_CLK);
localparam ACLO_COUNTER_WIDTH = log2(`ACLO_DELAY_CLK);

reg [DCLO_COUNTER_WIDTH-1:0] dclo_cnt;
reg [ACLO_COUNTER_WIDTH-1:0] aclo_cnt;
reg [1:0] reset;
reg aclo_out, dclo_out;

assign dclo = dclo_out;
assign aclo = aclo_out;

always @(posedge clk) begin
	//
	// Resolve metastability issues
	//
	reset[0] <= button | plock;
	reset[1] <= reset[0];
	
	if (reset[1]) begin
		dclo_cnt  	<= 0;
		aclo_cnt  	<= 0;
		aclo_out		<= 1'b1;
		dclo_out		<= 1'b1;
	end else begin
		//
		// Count the DCLO pulse
		//
		if (dclo_cnt != `DCLO_WIDTH_CLK) dclo_cnt <= dclo_cnt + 1'b1;
			else dclo_out <= 1'b0;
			
		//
		// After DCLO completion start count the ACLO pulse
		//
		if (!dclo_out) begin
			if (aclo_cnt != `ACLO_DELAY_CLK) aclo_cnt <= aclo_cnt + 1'b1;
				else aclo_out <= 1'b0;
		end
	end
end

function integer log2(input integer value);
begin
	for (log2=0; value>0; log2=log2+1) 
		value = value >> 1;
end
endfunction

endmodule

////////////////////////////////////////////////////////////////////////////////
// 
// Top interface for MIST
//

module bk0011m(
   input  wire [1:0]  CLOCK_27,            // Input clock 27 MHz

   output wire [5:0]  VGA_R,
   output wire [5:0]  VGA_G,
   output wire [5:0]  VGA_B,
   output wire        VGA_HS,
   output wire        VGA_VS,
	 
   output wire        LED,

   output wire        AUDIO_L,
   output wire        AUDIO_R,

   input  wire        SPI_SCK,
   output wire        SPI_DO,
   input  wire        SPI_DI,
   input  wire        SPI_SS2,
   input  wire        SPI_SS3,
   input  wire        SPI_SS4,
   input  wire        CONF_DATA0,

   output wire [12:0] SDRAM_A,
   inout  wire [15:0] SDRAM_DQ,
   output wire        SDRAM_DQML,
   output wire        SDRAM_DQMH,
   output wire        SDRAM_nWE,
   output wire        SDRAM_nCAS,
   output wire        SDRAM_nRAS,
   output wire        SDRAM_nCS,
   output wire [1:0]  SDRAM_BA,
   output wire        SDRAM_CLK,
   output wire        SDRAM_CKE
);

//______________________________________________________________________________
//
// Clocks
//

wire clk_120mhz, clk_120mhzS, clk_24mhz, clk_psg, plock;

pll pll(
	.inclk0(CLOCK_27[0]),
	.c0(clk_120mhz),  		//120MHz, 0 deg
	.c1(clk_120mhzS),  		//120MHz, 60 deg
	.c2(clk_24mhz),    		//24MHz
	.c3(clk_psg),    			//1.71MHz
	.locked(plock)
);

reg [1:0] clk_24div;
reg [1:0] clk_246div;
always @(posedge clk_24mhz) begin
	clk_24div  <= clk_24div  + 1'd1;
	clk_246div <= clk_246div + 1'd1;
	if(clk_246div == 2'd2) begin
		wb_clk  <= ~wb_clk;
		clk_cpu <= wb_cyc ? wb_clk : wb_clk ? 1'b0 : !dsk_copy;
		clk_246div <= 2'd0;
	end
end

assign SDRAM_CLK = clk_120mhzS;
wire   clk_ram   = clk_120mhz;
wire   clk_6mhz  = clk_24div[1];
wire   clk_037   = clk_6mhz;
wire   clk_pix   = clk_24mhz;
reg    wb_clk;   //4MHz
reg    clk_cpu;  //4MHz with waits

//______________________________________________________________________________
//
// MIST ARM I/O
//

wire        PS2_CLK;
wire        PS2_DAT;

wire [7:0]  joystick_0;
wire [7:0]  joystick_1;
wire [1:0]  buttons;
wire [1:0]  switches;
wire		   scandoubler_disable;
wire [7:0]  status;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire        sd_conf;
wire        sd_sdhc;
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire        sd_din_strobe;
wire        sd_mounted;

reg [9:0]   clk14k_div;
reg         clk_ps2;

always @(posedge clk_24mhz) begin
	clk14k_div <= clk14k_div + 9'd1;
	if(clk14k_div >= 10'd855) begin
		clk14k_div <= 0;
		clk_ps2 <= !clk_ps2;
	end
end

user_io #(.STRLEN(47)) user_io (
	.*,
	.conf_str("BK0011M;;F4,DSK;S3,VHD;O1,Color,On,Off;T2,Reset"),

	// ps2 keyboard emulation
	.ps2_clk(clk_ps2),				// 12-16khz provided by core
	.ps2_kbd_clk(PS2_CLK),
	.ps2_kbd_data(PS2_DAT),
	
	// unused
	.joystick_analog_0(),
	.joystick_analog_1(),
	.serial_data(),
	.serial_strobe()
);

assign LED = !dsk_copy;

//______________________________________________________________________________
//
// CPU
//

wire 			sys_init;
wire 			vm_dclo_in;
wire 			vm_aclo_in;
wire  [3:1]	vm_irq = {1'b0, wb_irq2, (key_stop && !key_stop_block)};
wire			vm_virq;
wire			vm_istb;
wire			vm_iack;
wire [15:0]	vm_ivec;
wire [15:0]	wb_adr;
wire [15:0] wb_out;
wire			wb_cyc;
wire			wb_we;
wire  [1:0]	wb_sel;

wire [15:0] wb_in;
wire			wb_ack;
wire  [2:1]	vm_sel;
wire			wb_stb;

wire [15:0] wb_dat_i = wb_out;

cpu_reset reset
(
	.clk(CLOCK_27[0]),
	.button(buttons[1] || status[0] || status[2]),
	.plock(~plock || !sys_ready),
	.dclo(vm_dclo_in),
	.aclo(vm_aclo_in)
);

// Wait for bk0011m.rom loading
reg sys_ready = 1'b0;
integer initwait;
always @(posedge wb_clk) begin
	if(!sys_ready) begin
		if(initwait < 5000000) begin 
			initwait <= initwait + 1;
		end else begin
			sys_ready <= 1'b1;
		end
	end
end

vm1_wb cpu
(
   .vm_clk_p(clk_cpu), 			// positive processor clock
   .vm_clk_n(~clk_cpu), 		// negative processor clock
   .vm_clk_slow(1'b0),  		// slow clock sim mode
   .vm_clk_ena(1'b1),   		// slow clock strobe
   .vm_clk_tve(1'b1),    		// VE-timer clock enable
   .vm_clk_sp(1'b0),   			// external pin SP clock
										//
   .vm_pa(2'b00),             // processor number
   .vm_init_in(1'b0), 			// peripheral reset
   .vm_init_out(sys_init),		// peripheral reset
   .vm_dclo(vm_dclo_in),		// processor reset
   .vm_aclo(vm_aclo_in), 		// power fail notoficaton
   .vm_irq(vm_irq), 				// radial interrupt requests
   .vm_virq(vm_virq),			// vectored interrupt request
										//
	.wbm_gnt_i(1'b1),				// master wishbone granted
	.wbm_adr_o(wb_adr),			// master wishbone address
	.wbm_dat_o(wb_out),			// master wishbone data output
   .wbm_dat_i(wb_in),			// master wishbone data input
	.wbm_cyc_o(wb_cyc),			// master wishbone cycle
	.wbm_we_o (wb_we),			// master wishbone direction
	.wbm_sel_o(wb_sel),			// master wishbone byte election
	.wbm_stb_o(wb_stb),			// master wishbone strobe
	.wbm_ack_i(wb_ack),			// master wishbone acknowledgement
										//
	.wbi_dat_i(vm_ivec),			// interrupt vector input
	.wbi_stb_o(vm_istb),			// interrupt vector strobe
	.wbi_ack_i(vm_iack),			// interrupt vector acknowledgement
										//
	.wbs_adr_i(wb_adr[3:0]),	// slave wishbone address
   .wbs_dat_i(wb_out),			// slave wishbone data input
	.wbs_cyc_i(cpureg_sel),		// slave wishbone cycle
	.wbs_we_i (wb_we),			// slave wishbone direction
	.wbs_stb_i(wb_stb),	  		// slave wishbone strobe
	.wbs_ack_o(cpureg_ack),		// slave wishbone acknowledgement
	.wbs_dat_o(cpureg_dout),	// slave wishbone data output
										//
   .vm_reg14(port_data),		// register 177714 data input
   .vm_reg16({9'b110000001, ~key_down, 2'b00, super_flg, 3'b000}),	// register 177716 data input
   .vm_sel(vm_sel)    			// register select outputs
);

wire [15:0]	cpureg_dout;
wire [15:0]	cpureg_data = (cpureg_sel && !wb_we) ? cpureg_dout : 16'd0;
wire        cpureg_sel  = wb_cyc & (wb_adr[15:4] == (16'o177700 >> 4));
wire        cpureg_ack;

assign wb_ack    = cpureg_ack  | keyboard_ack  | scrreg_ack  | ram_ack | disk_ack;
assign wb_in     = cpureg_data | keyboard_data | scrreg_data | ram_data;

wire sysreg_write = wb_stb & vm_sel[1] & wb_we;
wire port_write   = wb_stb & vm_sel[2] & wb_we;

reg super_flg = 1'b0;
wire sysreg_acc   = wb_stb & vm_sel[1];

always @(posedge sysreg_acc) begin
	if(wb_we) begin 
		if((!wb_sel[1] || (!wb_out[11] && wb_sel[1])) && wb_sel[0]) super_flg <= wb_out[3];
	end else begin 
		super_flg <= 1'b0;
	end
end

//______________________________________________________________________________
//
// Memory
//

wire [15:0]	ram_data;
wire        ram_ack;
wire  [1:0] screen_write;

sram_wb ram(
	.*,

	.init(!plock),
	
   .wb_dat_o(ram_data),
	.wb_ack(ram_ack),

	.mem_copy(dsk_copy),
	.mem_copy_virt(dsk_copy_virt),
	.mem_copy_addr(dsk_copy_addr),
	.mem_copy_data_i(dsk_copy_data_o),
	.mem_copy_data_o(dsk_copy_data_i),
	.mem_copy_we(dsk_copy_we),
	.mem_copy_rd(dsk_copy_rd)
);


//______________________________________________________________________________
//
// Vectorized interrupts manager.
//
										  
wire virq_req60, virq_req274;
wire virq_ack60, virq_ack274;

vic_wb #(.N(2)) vic 
(
	.wb_clk_i(wb_clk),
	.wb_rst_i(sys_init),
	.wb_irq_o(vm_virq),	
	.wb_dat_o(vm_ivec),
	.wb_stb_i(vm_istb),
	.wb_ack_o(vm_iack),
	.ivec({16'o000060,  16'o000274}),
	.ireq({virq_req60, virq_req274}),
	.iack({virq_ack60, virq_ack274})
);

//______________________________________________________________________________
//
// Keyboard & Mouse & Joystick
//
reg  key_stop_block;
always @(posedge sysreg_write) if(!wb_out[11] && wb_sel[1]) key_stop_block <= wb_out[12];

wire        key_down;
wire        key_stop;
wire [15:0]	keyboard_data;
wire        keyboard_ack;

keyboard_wb keyboard(
	.*,
   .wb_dat_o(keyboard_data),
	.wb_ack(keyboard_ack)
);

reg joystick_or_mouse = 1'b0;
wire [15:0] port_data = joystick_or_mouse ? mouse_state : joystick_state;

wire [15:0] joystick_state  = {7'b0000000, joystick};
wire  [7:0] joystick =  joystick_0 |  joystick_1;
wire use_joystick = (joystick != 8'd0);

always @(posedge use_joystick, posedge mouse_data_ready) begin
	if(use_joystick) joystick_or_mouse <= 1'b0;
		else joystick_or_mouse <= 1'b1;
end

wire ps2_mouse_clk;
wire ps2_mouse_data;
wire left_btn, right_btn;
wire mouse_data_ready;
wire [8:0] pointer_dx;
wire [8:0] pointer_dy;
wire [7:0] mouse_counter;
reg  [7:0] old_mouse_counter;

ps2_mouse mouse(
	.*,
	.clk(wb_clk),
	.ps2_clk(ps2_mouse_clk),
	.ps2_data(ps2_mouse_data),
	.data_ready(mouse_data_ready),
	.counter(mouse_counter)
);

reg [15:0] mouse_state  = 16'd0;
reg        mouse_enable = 1'b0;
wire       mouse_write  = wb_sel[0] & port_write;
always @(posedge wb_clk) begin
	if(mouse_write) begin 
		mouse_enable <= wb_out[3];
		if(!wb_out[3]) mouse_state[3:0] = 4'b0000;
	end else begin
		mouse_state[6] <= right_btn;
		mouse_state[5] <= left_btn;
		if(mouse_enable) begin
			if(old_mouse_counter != mouse_counter) begin
				if(!mouse_state[0] && !mouse_state[2]) begin
					if(!pointer_dy[8] && ( pointer_dy > 3)) mouse_state[0] <= 1'b1;
					if( pointer_dy[8] && (~pointer_dy > 2)) mouse_state[2] <= 1'b1;
				end
				if(!mouse_state[1] && !mouse_state[3]) begin
					if(!pointer_dx[8] && ( pointer_dx > 3)) mouse_state[1] <= 1'b1;
					if( pointer_dx[8] && (~pointer_dx > 2)) mouse_state[3] <= 1'b1;
				end
				old_mouse_counter <= mouse_counter;
			end
		end
	end
end


//______________________________________________________________________________
//
// Audio 
//

reg spk_out;
always @(posedge sysreg_write) if((!wb_sel[1] || (!wb_out[11] && wb_sel[1])) && wb_sel[0]) spk_out <= wb_out[6];
wire [7:0] channel_a;
wire [7:0] channel_b;
wire [7:0] channel_c;

sigma_delta_dac #(.MSBI(10)) dac_l (
	.CLK(wb_clk),
	.RESET(sys_init),
	.DACin({1'b0, channel_a, 1'b0} + {2'b00, channel_b} + {1'b00, spk_out, 7'b0000000}),
	.DACout(AUDIO_L)
);

sigma_delta_dac #(.MSBI(10)) dac_r(
	.CLK(wb_clk),
	.RESET(sys_init),
	.DACin({1'b0, channel_c, 1'b0} + {2'b00, channel_b} + {1'b00, spk_out, 7'b0000000}),
	.DACout(AUDIO_R)
);

ay8910 ay8910(
	.CLK(clk_psg),
	.EN(1'b1),
	.RESET(sys_init),
   .BDIR(vm_sel[2] & wb_we & wb_stb),
	.CS(1'b1),
   .BC(wb_sel[1]),
   .DI(~wb_dat_i[7:0]),
   .CHANNEL_A(channel_a),
   .CHANNEL_B(channel_b),
   .CHANNEL_C(channel_c)
);


//______________________________________________________________________________
//
// Video 
//
wire [15:0]	scrreg_data;
wire        scrreg_ack;
wire        wb_irq2;

wire video_stb = wb_we & wb_cyc & wb_stb & (screen_write[1] | screen_write[0]);

video video(
	.*,
	.color(~status[1]),
	.cache_addr({screen_write[1], wb_adr[13:0]}),
	.cache_data(wb_out),
	.cache_wtbt(wb_sel),
	.cache_we(video_stb),
	
   .wb_dat_o(scrreg_data),
	.wb_ack(scrreg_ack)
);

//______________________________________________________________________________
//
// Disk I/O
//

wire        disk_ack;

wire        dsk_copy;
wire        dsk_copy_virt;
wire [24:0] dsk_copy_addr;
wire [15:0] dsk_copy_data_i;
wire [15:0] dsk_copy_data_o;
wire        dsk_copy_we;
wire        dsk_copy_rd;

disk_wb disk(.*, .reset(buttons[1] || status[2]), .wb_ack(disk_ack));

endmodule
