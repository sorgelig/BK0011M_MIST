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

`define 	DCLO_WIDTH_CLK	  24   //  >5ms for 27MHz
`define	ACLO_DELAY_CLK	  240  // >70ms for 27MHz

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
		dclo_cnt <= 0;
		aclo_cnt <= 0;
		aclo_out <= 1;
		dclo_out <= 1;
	end else begin
		//
		// Count the DCLO pulse
		//
		if (dclo_cnt != `DCLO_WIDTH_CLK) dclo_cnt <= dclo_cnt + 1'b1;
			else dclo_out <= 0;
			
		//
		// After DCLO completion start count the ACLO pulse
		//
		if (!dclo_out) begin
			if (aclo_cnt != `ACLO_DELAY_CLK) aclo_cnt <= aclo_cnt + 1'b1;
				else aclo_out <= 0;
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

module bk0011m
(
   input         CLOCK_27, // Input clock 27 MHz

   output  [5:0] VGA_R,
   output  [5:0] VGA_G,
   output  [5:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,
	 
   output        LED,

   output        AUDIO_L,
   output        AUDIO_R,

   input         SPI_SCK,
   output        SPI_DO,
   input         SPI_DI,
   input         SPI_SS2,
   input         SPI_SS3,
   input         SPI_SS4,
   input         CONF_DATA0,

   output [12:0] SDRAM_A,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nWE,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nCS,
   output  [1:0] SDRAM_BA,
   output        SDRAM_CLK,
   output        SDRAM_CKE
);

//______________________________________________________________________________
//
// Clocks
//

wire clk_24mhz, clk_psg, plock;

pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk_ram),
	.c1(SDRAM_CLK),
	.c2(clk_24mhz),
	.c3(clk_psg),    //1.71MHz
	.locked(plock)
);

reg [1:0] clk_24div;
reg [1:0] clk_246div;
always @(posedge clk_24mhz) begin
	clk_24div  <= clk_24div  + 1'd1;
	clk_246div <= clk_246div + 1'd1;
	if(clk_246div == (2'd2 + bk0010)) begin
		clk_bus <= ~clk_bus;
		clk_246div <= 2'd0;
	end
end

wire   clk_ram;
wire   clk_6mhz  = clk_24div[1];
wire   clk_037   = clk_6mhz;
wire   clk_pix   = clk_24mhz;
reg    clk_bus;  //4MHz or 3MHz

//______________________________________________________________________________
//
// MIST ARM I/O
//

wire        PS2_CLK;
wire        PS2_DAT;

wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire  [7:0] status;

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

reg   [9:0] clk14k_div;
reg         clk_ps2;

always @(posedge clk_24mhz) begin
	clk14k_div <= clk14k_div + 9'd1;
	if(clk14k_div >= 10'd855) begin
		clk14k_div <= 0;
		clk_ps2 <= !clk_ps2;
	end
end

user_io #(.STRLEN(89)) user_io
(
	.*,
	.conf_str
	(
        "BK0011M;BIN;F4,DSK;S3,VHD;O1,Color,On,Off;O5,Model,BK0011M,BK0010;O6,Disk,On,Off;T2,Reset"
	),

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

wire        cpu_dclo;
wire        cpu_aclo;
wire  [3:1]	cpu_irq = {1'b0, irq2, (key_stop && !key_stop_block)};
wire        cpu_virq;
wire        cpu_iacko;
wire [15:0] cpu_dout;
wire [15:0] cpu_din;
wire        cpu_din_out;
wire        cpu_dout_in;
wire        cpu_dout_out;
reg         cpu_ack;
wire  [2:1]	cpu_psel;
wire        bus_reset;
wire [15:0] bus_din = cpu_dout;
wire [15:0]	bus_addr;
wire        bus_sync;
wire        bus_we;
wire  [1:0]	bus_wtbt;
wire        bus_stb = cpu_dout_d | cpu_din_out;

cpu_reset reset
(
	.clk(CLOCK_27),
	.button(buttons[1] || status[0] || status[2] || key_reset),
	.plock(~plock || !sys_ready || reset_req),
	.dclo(cpu_dclo),
	.aclo(cpu_aclo)
);

// Wait for bk0011m.rom loading
reg sys_ready = 1'b0;
integer initwait;
always @(posedge clk_bus) begin
	if(!sys_ready) begin
		if(initwait < 5000000) initwait <= initwait + 1;
			else sys_ready <= 1'b1;
	end
end

vm1 cpu
(
	.pin_clk(clk_bus),
	.pin_init(bus_reset),
	.pin_dclo(cpu_dclo),
	.pin_aclo(cpu_aclo),

	.pin_irq(cpu_irq),
	.pin_virq(cpu_virq),
	.pin_iako(cpu_iacko),

	.pin_addr(bus_addr),
	.pin_dout(cpu_dout),
	.pin_din(cpu_din),
	.pin_din_in(cpu_din_out),
	.pin_din_out(cpu_din_out),
	.pin_dout_in(cpu_dout_d),
	.pin_dout_out(cpu_dout_out),
	.pin_we(bus_we),
	.pin_wtbt(bus_wtbt),
	.pin_sync(bus_sync),
	.pin_rply(cpu_ack),

	.pin_dmr(dsk_copy),
	.pin_sack(0),

	.pin_sel(cpu_psel)
);

reg   [2:0] dout_delay;
wire cpu_dout_d = dout_delay[{~bk0010,1'b0}] & cpu_dout_out;
always @(negedge clk_bus) dout_delay <= {dout_delay[1:0], cpu_dout_out};

wire sysreg_sel   = cpu_psel[1];
wire port_sel     = cpu_psel[2];

wire [15:0]	cpureg_data = (bus_sync & !cpu_psel & (bus_addr[15:4] == (16'o177700 >> 4))) ? cpu_dout : 16'd0;
wire [15:0]	sysreg_data = sysreg_sel ? {start_addr, 1'b1, ~key_down, 3'b000, super_flg, 2'b00} : 16'd0;

always @(posedge clk_bus) cpu_ack <= keyboard_ack | scrreg_ack | ram_ack | disk_ack | ivec_ack;
assign cpu_din    = cpureg_data | keyboard_data | scrreg_data | ram_data | sysreg_data | port_data | ivec_data;

wire sysreg_write = bus_stb & sysreg_sel & bus_we;
wire port_write   = bus_stb & port_sel   & bus_we;

reg  super_flg  = 1'b0;
wire sysreg_acc = bus_stb & sysreg_sel;
always @(posedge sysreg_acc) super_flg <= bus_we;

//______________________________________________________________________________
//
// Memory
//

wire [15:0]	ram_data;
wire        ram_ack;
wire  [1:0] screen_write;
reg         bk0010     = 1'bZ;
reg         disk_rom   = 1'bZ;
wire  [7:0] start_addr;
wire [15:0] ext_mode;
reg         cold_start = 1'b1;
reg         mode_start = 1'b1;
wire        bk0010_stub;

memory_wb memory
(
	.*,

	.init(!plock),
	.sysreg_sel(sysreg_sel),

	.bus_dout(ram_data),
	.bus_ack(ram_ack),

	.mem_copy(dsk_copy),
	.mem_copy_virt(dsk_copy_virt),
	.mem_copy_addr(dsk_copy_addr),
	.mem_copy_data_i(dsk_copy_data_o),
	.mem_copy_data_o(dsk_copy_data_i),
	.mem_copy_we(dsk_copy_we),
	.mem_copy_rd(dsk_copy_rd)
);

integer reset_time;
always @(posedge clk_bus) begin
	reg old_dclo, old_sel, old_bk0010, old_disk_rom;
	old_dclo <= cpu_dclo;
	old_sel  <= sysreg_sel;

	if(!old_dclo && cpu_dclo) begin 
		reset_time = 0;
		old_bk0010   <= bk0010;
		old_disk_rom <= disk_rom;
	end

	if(cpu_dclo) begin 
		reset_time++;
		bk0010     <= status[5];
		disk_rom   <= ~status[6];
		cold_start <= (old_bk0010 != bk0010) || (old_disk_rom != disk_rom) || (reset_time >= 1500000*2);
		mode_start <= 1'b1;
	end
	
	if(old_sel && !sysreg_sel) mode_start <= 1'b0;
end

//______________________________________________________________________________
//
// Vectorized interrupts manager.
//

wire [15:0]	ivec_o;
wire [15:0] ivec_data = ivec_sel ? ivec_o : 16'd0;

wire ivec_sel = cpu_iacko & !bus_we;
wire ivec_ack;

wire virq_req60, virq_req274;
wire virq_ack60, virq_ack274;

vic_wb #(.N(2)) vic 
(
	.wb_clk_i(clk_bus),
	.wb_rst_i(bus_reset),
	.wb_irq_o(cpu_virq),	
	.wb_dat_o(ivec_o),
	.wb_stb_i(ivec_sel & bus_stb),
	.wb_ack_o(ivec_ack),
	.ivec({16'o000060,  16'o000274}),
	.ireq({virq_req60, virq_req274}),
	.iack({virq_ack60, virq_ack274})
);

//______________________________________________________________________________
//
// Keyboard & Mouse & Joystick
//
reg  key_stop_block;
always @(posedge sysreg_write) if(!cpu_dout[11] && bus_wtbt[1]) key_stop_block <= cpu_dout[12];

wire        key_down;
wire        key_stop;
wire        key_reset;
wire        key_color;
wire [15:0]	keyboard_data;
wire        keyboard_ack;

keyboard_wb keyboard
(
	.*,
	.scan_mode(0),
	.bus_dout(keyboard_data),
	.bus_ack(keyboard_ack)
);

reg joystick_or_mouse = 1'b0;
wire [15:0] port_data = port_sel ? (joystick_or_mouse ? mouse_state : joystick_state) : 16'd0;

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

ps2_mouse mouse
(
	.*,
	.clk(clk_bus),
	.ps2_clk(ps2_mouse_clk),
	.ps2_data(ps2_mouse_data),
	.data_ready(mouse_data_ready),
	.counter(mouse_counter)
);

reg [15:0] mouse_state  = 16'd0;
reg        mouse_enable = 1'b0;
wire       mouse_write  = bus_wtbt[0] & port_write;
always @(posedge clk_bus) begin
	if(mouse_write) begin 
		mouse_enable <= cpu_dout[3];
		if(!cpu_dout[3]) mouse_state[3:0] = 4'b0000;
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
always @(posedge sysreg_write) if((!bus_wtbt[1] || (!cpu_dout[11] && bus_wtbt[1])) && bus_wtbt[0]) spk_out <= cpu_dout[6];
wire [7:0] channel_a;
wire [7:0] channel_b;
wire [7:0] channel_c;

sigma_delta_dac #(.MSBI(10)) dac_l
(
	.CLK(clk_24mhz),
	.RESET(bus_reset),
	.DACin({1'b0, channel_a, 1'b0} + {2'b00, channel_b} + {2'b00, spk_out, 7'b0000000}),
	.DACout(AUDIO_L)
);

sigma_delta_dac #(.MSBI(10)) dac_r
(
	.CLK(clk_24mhz),
	.RESET(bus_reset),
	.DACin({1'b0, channel_c, 1'b0} + {2'b00, channel_b} + {2'b00, spk_out, 7'b0000000}),
	.DACout(AUDIO_R)
);

ym2149 psg
(
	.CLK(clk_psg),
	.RESET(bus_reset),
	.BDIR(port_write),
	.BC(bus_wtbt[1]),
	.DI(~bus_din[7:0]),
	.CHANNEL_A(channel_a),
	.CHANNEL_B(channel_b),
	.CHANNEL_C(channel_c),
	.SEL(0),
	.MODE(0)
);


//______________________________________________________________________________
//
// Video 
//
wire [15:0]	scrreg_data;
wire        scrreg_ack;
wire        irq2;

video video
(
	.*,
	.color(~status[1]),
	.mode(scandoubler_disable),
	.color_switch(key_color),

	.bus_dout(scrreg_data),
	.bus_ack(scrreg_ack)
);


//______________________________________________________________________________
//
// Disk I/O
//
wire        disk_ack;
wire        reset_req;
wire        dsk_copy;
wire        dsk_copy_virt;
wire [24:0] dsk_copy_addr;
wire [15:0] dsk_copy_data_i;
wire [15:0] dsk_copy_data_o;
wire        dsk_copy_we;
wire        dsk_copy_rd;

disk_wb disk(.*, .reset(cpu_dclo), .bus_ack(disk_ack));

endmodule
