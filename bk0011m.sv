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


/////////////////////////////   CLOCKS   //////////////////////////////
wire plock;
wire clk_sys;

pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk_sys),
	.c1(SDRAM_CLK),
	.locked(plock)
);

reg  ce_cpu_p;
reg  ce_cpu_n;
wire ce_bus = ce_cpu_p;
reg  ce_psg;
reg  ce_12mp;
reg  ce_12mn;
reg  ce_6mp;
reg  ce_6mn;
reg  turbo;

always @(negedge clk_sys) begin
	reg  [3:0] div = 0;
	reg  [4:0] cpu_div = 0;
	reg  [5:0] psg_div = 0;

	cpu_div <= cpu_div + 1'd1;
	if(cpu_div == ((5'd23 + {bk0010, 3'b000})>>turbo)) begin
		cpu_div <= 0;
		if(!bus_sync) turbo <= status[1];
	end
	ce_cpu_p <= (cpu_div == 0);
	ce_cpu_n <= (cpu_div == (5'd12 + {bk0010, 2'b00})>>turbo);

	div <= div + 1'd1;
	ce_12mp <= !div[2] & !div[1:0];
	ce_12mn <=  div[2] & !div[1:0];
	ce_6mp  <= !div[3] & !div[2:0];
	ce_6mn  <=  div[3] & !div[2:0];

	psg_div <= psg_div + 1'd1;
	if(psg_div == 55) psg_div <= 0;

	ce_psg <= !psg_div;
end


///////////////////////////  MIST ARM I/O  ////////////////////////////
wire        ps2_kbd_clk;
wire        ps2_kbd_data;
wire        ps2_mouse_clk;
wire        ps2_mouse_data;
wire        ps2_caps_led;

wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire [31:0] status;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_conf;
wire        sd_sdhc;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_mounted;

`include "build_id.v"
localparam CONF_STR = 
{
	"BK0011M;BINDSK;",
	"S3,VHD;",
	"O78,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"O1,CPU Speed,3MHz/4MHz,6MHz/8MHz;",
	"O56,Model,BK0011M & DSK,BK0010 & DSK,BK0011M,BK0010;",
	"T2,Reset & Unload Disk;",
	"V,v2.50.",`BUILD_DATE
};

user_io #(.STRLEN(($size(CONF_STR)>>3))) user_io
(
	.*,
	.conf_str(CONF_STR),

	// unused
	.img_size(),
	.joystick_analog_0(),
	.joystick_analog_1()
);

assign LED = !dsk_copy;


//////////////////////////////   CPU   ////////////////////////////////
wire        cpu_dclo;
wire        cpu_aclo;
wire  [3:1]	cpu_irq = {1'b0, irq2, (key_stop && !key_stop_block)};
wire        cpu_virq;
wire        cpu_iacko;
wire [15:0] cpu_dout;
wire        cpu_din_out;
wire        cpu_dout_out;
reg         cpu_ack;
wire  [2:1]	cpu_psel;
wire        bus_reset;
wire [15:0] bus_din = cpu_dout;
wire [15:0]	bus_addr;
wire        bus_sync;
wire        bus_we;
wire  [1:0]	bus_wtbt;
wire        bus_stb = cpu_dout_in | cpu_din_out;

vm1_reset reset
(
	.clk(CLOCK_27),
	.reset(!sys_ready | reset_req | buttons[1] | status[2] | key_reset),
	.dclo(cpu_dclo),
	.aclo(cpu_aclo)
);

// Wait for bk0011m.rom
reg sys_ready = 0;
always @(posedge clk_sys) begin
	reg old_copy;
	old_copy <= dsk_copy;
	if(old_copy & ~dsk_copy) sys_ready <= 1;
end

vm1_se cpu
(
	.pin_clk(clk_sys),
	.pin_ce_p(ce_cpu_p),
	.pin_ce_n(ce_cpu_n),
	.pin_ce_timer(ce_cpu_p),

	.pin_init(bus_reset),
	.pin_dclo(cpu_dclo),
	.pin_aclo(cpu_aclo),

	.pin_irq(cpu_irq),
	.pin_virq(cpu_virq),
	.pin_iako(cpu_iacko),

	.pin_addr(bus_addr),
	.pin_dout(cpu_dout),
	.pin_din(cpu_din),
	.pin_din_stb_out(cpu_din_out),
	.pin_dout_stb_out(cpu_dout_out),
	.pin_din_stb_in(cpu_din_out),
	.pin_dout_stb_in(cpu_dout_in),
	.pin_we(bus_we),
	.pin_wtbt(bus_wtbt),
	.pin_sync(bus_sync),
	.pin_rply(cpu_ack),

	.pin_dmr(dsk_copy),
	.pin_sack(0),

	.pin_sel(cpu_psel)
);

wire        cpu_dout_in  = dout_delay[{~bk0010,1'b0}] & cpu_dout_out;
wire        sysreg_sel   = cpu_psel[1];
wire        port_sel     = cpu_psel[2];
wire [15:0]	cpureg_data  = (bus_sync & !cpu_psel & (bus_addr[15:4] == (16'o177700 >> 4))) ? cpu_dout : 16'd0;
wire [15:0]	sysreg_data  = sysreg_sel ? {start_addr, 1'b1, ~key_down, 3'b000, super_flg, 2'b00} : 16'd0;
wire [15:0] cpu_din      = cpureg_data | keyboard_data | scrreg_data | ram_data | sysreg_data | port_data | ivec_data;
wire        sysreg_write = bus_stb & sysreg_sel & bus_we;
wire        port_write   = bus_stb & port_sel   & bus_we;

reg   [2:0] dout_delay;
always @(negedge clk_sys) if(ce_bus) dout_delay <= {dout_delay[1:0], cpu_dout_out};
always @(negedge clk_sys) if(ce_bus) cpu_ack <= keyboard_ack | scrreg_ack | ram_ack | disk_ack | ivec_ack;

reg  super_flg  = 1'b0;
wire sysreg_acc = bus_stb & sysreg_sel;
always @(posedge clk_sys) begin
	reg old_acc;
	old_acc <= sysreg_acc;
	if(~old_acc & sysreg_acc) super_flg <= bus_we;
end


/////////////////////////////   MEMORY   //////////////////////////////
wire [15:0]	ram_data;
wire        ram_ack;
wire  [1:0] screen_write;
reg         bk0010     = 1'bZ;
reg         disk_rom   = 1'bZ;
wire  [7:0] start_addr;
wire [15:0] ext_mode;
reg         cold_start = 1;
reg         mode_start = 1;
wire        bk0010_stub;

memory memory
(
	.*,

	.init(!plock),
	.sysreg_sel(sysreg_sel),

	.bus_dout(ram_data),
	.bus_ack(ram_ack),

	.mem_copy(dsk_copy),
	.mem_copy_virt(dsk_copy_virt),
	.mem_copy_addr(dsk_copy_addr),
	.mem_copy_din(dsk_copy_dout),
	.mem_copy_dout(dsk_copy_din),
	.mem_copy_we(dsk_copy_we),
	.mem_copy_rd(dsk_copy_rd)
);

always @(posedge clk_sys) begin
	integer reset_time;
	reg old_dclo, old_sel, old_bk0010, old_disk_rom;

	old_dclo <= cpu_dclo;
	old_sel  <= sysreg_sel;

	if(!old_dclo & cpu_dclo) begin 
		reset_time   <= 10000000;
		old_bk0010   <= bk0010;
		old_disk_rom <= disk_rom;
	end else if(cpu_dclo) begin 
		if(ce_12mp && reset_time) reset_time <= reset_time - 1;
		bk0010     <= status[5];
		disk_rom   <= ~status[6];
		cold_start <= (old_bk0010 != bk0010) | (old_disk_rom != disk_rom) | !reset_time;
		mode_start <= 1;
	end

	if(old_sel && !sysreg_sel) mode_start <= 0;
end


///////////////////////////   INTERRUPTS   ////////////////////////////
wire [15:0]	ivec_o;
wire [15:0] ivec_data = ivec_sel ? ivec_o : 16'd0;

wire ivec_sel = cpu_iacko & !bus_we;
wire ivec_ack;

wire virq_req60, virq_req274;
wire virq_ack60, virq_ack274;

vic_wb #(2) vic 
(
	.clk_sys(clk_sys),
	.ce(ce_bus),
	.wb_rst_i(bus_reset),
	.wb_irq_o(cpu_virq),	
	.wb_dat_o(ivec_o),
	.wb_stb_i(ivec_sel & bus_stb),
	.wb_ack_o(ivec_ack),
	.ivec({16'o000060,  16'o000274}),
	.ireq({virq_req60, virq_req274}),
	.iack({virq_ack60, virq_ack274})
);


///////////////////   KEYBOARD, MOUSE, JOYSTICK   /////////////////////
reg key_stop_block;
always @(posedge clk_sys) begin
	reg old_write;
	old_write <= sysreg_write;
	if(~old_write & sysreg_write & ~cpu_dout[11] & bus_wtbt[1]) key_stop_block <= cpu_dout[12];
end

wire        key_down;
wire        key_stop;
wire        key_reset;
wire        key_color;
wire        key_bw;
wire [15:0]	keyboard_data;
wire        keyboard_ack;

keyboard keyboard
(
	.*,
	.bus_dout(keyboard_data),
	.bus_ack(keyboard_ack)
);

reg         joystick_or_mouse = 0;
wire [15:0] port_data = port_sel ? (joystick_or_mouse ? mouse_state : joystick) : 16'd0;
wire  [7:0] joystick =  joystick_0 | joystick_1;

always @(posedge clk_sys) begin
	if(|joystick)        joystick_or_mouse <= 0;
	if(mouse_data_ready) joystick_or_mouse <= 1;
end

wire        left_btn, right_btn;
wire        mouse_data_ready;
wire  [8:0] pointer_dx;
wire  [8:0] pointer_dy;
wire  [7:0] mouse_counter;
reg   [7:0] old_mouse_counter;

ps2_mouse mouse
(
	.*,
	.clk(clk_sys),
	.ps2_clk(ps2_mouse_clk),
	.ps2_data(ps2_mouse_data),
	.data_ready(mouse_data_ready),
	.counter(mouse_counter)
);

reg  [6:0] mouse_state  = 0;
wire       mouse_write  = bus_wtbt[0] & port_write;
always @(posedge clk_sys) begin
	reg mouse_enable = 0;
	reg old_write;
	old_write <= mouse_write;

	if(~old_write & mouse_write) begin 
		mouse_enable <= cpu_dout[3];
		if(!cpu_dout[3]) mouse_state[3:0] <= 0;
	end else begin
		mouse_state[6] <= right_btn;
		mouse_state[5] <= left_btn;
		if(mouse_enable) begin
			if(old_mouse_counter != mouse_counter) begin
				if(!mouse_state[0] && !mouse_state[2]) begin
					if(!pointer_dy[8] && ( pointer_dy > 3)) mouse_state[0] <= 1;
					if( pointer_dy[8] && (~pointer_dy > 2)) mouse_state[2] <= 1;
				end
				if(!mouse_state[1] && !mouse_state[3]) begin
					if(!pointer_dx[8] && ( pointer_dx > 3)) mouse_state[1] <= 1;
					if( pointer_dx[8] && (~pointer_dx > 2)) mouse_state[3] <= 1;
				end
				old_mouse_counter <= mouse_counter;
			end
		end
	end
end


/////////////////////////////   AUDIO   ///////////////////////////////
reg [2:0] spk_out;
always @(posedge clk_sys) begin
	reg old_write;
	old_write <= sysreg_write;
	if(~old_write & sysreg_write) begin
		if((!bus_wtbt[1] || (!cpu_dout[11] && bus_wtbt[1])) && bus_wtbt[0]) spk_out <= {cpu_dout[6],cpu_dout[5],cpu_dout[2] & !bk0010};
	end
end

wire [7:0] channel_a;
wire [7:0] channel_b;
wire [7:0] channel_c;
wire [5:0] psg_active;

sigma_delta_dac #(.MSBI(9)) dac_l
(
	.CLK(clk_sys),
	.RESET(bus_reset),
	.DACin(psg_active ? {1'b0, channel_a, 1'b0} + {2'b00, channel_b} + {2'b00, spk_out, 5'b00000} : {spk_out, 7'b0000000}),
	.DACout(AUDIO_L)
);

sigma_delta_dac #(.MSBI(9)) dac_r
(
	.CLK(clk_sys),
	.RESET(bus_reset),
	.DACin(psg_active ? {1'b0, channel_c, 1'b0} + {2'b00, channel_b} + {2'b00, spk_out, 5'b00000} : {spk_out, 7'b0000000}),
	.DACout(AUDIO_R)
);

ym2149 psg
(
	.CLK(clk_sys),
	.CE(ce_psg),
	.RESET(bus_reset),
	.BDIR(port_write),
	.BC(bus_wtbt[1]),
	.DI(~bus_din[7:0]),
	.CHANNEL_A(channel_a),
	.CHANNEL_B(channel_b),
	.CHANNEL_C(channel_c),
	.ACTIVE(psg_active),
	.SEL(0),
	.MODE(0)
);


/////////////////////////////   VIDEO   ///////////////////////////////
wire [15:0]	scrreg_data;
wire        scrreg_ack;
wire        irq2;
wire [13:0] vram_addr;
wire [15:0] vram_data;

video video
(
	.*,
	.reset(cpu_dclo),
	.color_switch(key_color),
	.bw_switch(key_bw),
	.scale(status[8:7]),

	.bus_dout(scrreg_data),
	.bus_ack(scrreg_ack)
);


//////////////////////////   DISK, TAPE   /////////////////////////////
wire        disk_ack;
wire        reset_req;
wire        dsk_copy;
wire        dsk_copy_virt;
wire [24:0] dsk_copy_addr;
wire [15:0] dsk_copy_din;
wire [15:0] dsk_copy_dout;
wire        dsk_copy_we;
wire        dsk_copy_rd;

disk disk(.*, .reset(cpu_dclo), .reset_full(status[2]), .bus_ack(disk_ack));

endmodule
