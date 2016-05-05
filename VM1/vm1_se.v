//
//
// 1801VM1 simplified WB-like positive synchronous interface with Q-BUS timings
// (C) 2016 Sorgelig
//
//

module vm1_se
(
   input         pin_clk,          // system clock
   input         pin_ce_p,         // positive clock enable
   input         pin_ce_n,         // negative clock enable
	input         pin_ce_timer,     // timer clock enable

   input         pin_dclo,         // processor reset
   input         pin_aclo,         // power fail notoficaton
   output        pin_init,         // peripheral reset

   input   [3:1] pin_irq,          // radial interrupt requests
   input         pin_virq,         // vectored interrupt request
   output        pin_iako,         // interrupt vector input

   input         pin_dmr,          // DMA request
   output        pin_dmgo,         // DMA grant
   input         pin_sack,         // DMA sync

   output [15:0] pin_addr,         // address bus
   output [15:0] pin_dout,         // data out bus
   input  [15:0] pin_din,          // data in bus
   output        pin_sync,         // address strobe
   output        pin_we,           // write cycle helper
   output        pin_din_stb_out,  // master strobe out for data in
   output        pin_dout_stb_out, // master strobe out for data out
   input         pin_din_stb_in,   // slave (for internal parts) strobe in for data in
   input         pin_dout_stb_in,  // slave (for internal parts) strobe in for data out
   output  [1:0] pin_wtbt,         // write/byte status
   input         pin_rply,         // transaction reply
   output        pin_bsy,          // bus busy flag

   output  [2:1] pin_sel           // register select outputs
);

//______________________________________________________________________________
//

assign pin_addr    = addr;
assign pin_we      = write & pin_sync;
assign pin_wtbt[0] = (wtbt & ~addr[0]) | ~wtbt;
assign pin_wtbt[1] = (wtbt &  addr[0]) | ~wtbt;

wire   rply, wtbt, rmw;

reg        write;
reg [15:0] addr;

always @(posedge pin_clk) begin
	reg old_sync, old_din;
	reg rmw_mode;
	old_sync <= pin_sync;
	old_din <= pin_din_stb_out;
	
	if(!old_sync & pin_sync) begin
		addr  <= pin_dout;
		write <= wtbt;
		rmw_mode <= rmw;
	end

	if(old_din & !pin_din_stb_out & rmw_mode & pin_sync) write <= 1; //Next is write for RMW.
	if(old_sync & !pin_sync) write <= 0;
end

vm1_qbus_se core
(
   .pin_clk       (pin_clk),
   .pin_ce_p      (pin_ce_p),
   .pin_ce_n      (pin_ce_n),
   .pin_ce_timer  (pin_ce_timer),

   .pin_init_in   (0),
   .pin_init_out  (pin_init),
   .pin_dclo      (pin_dclo),
   .pin_aclo      (pin_aclo),
   .pin_irq       (pin_irq),
   .pin_virq      (pin_virq),

   .pin_ad_in     (pin_din_stb_out ? pin_din : pin_dout),
   .pin_ad_out    (pin_dout),

   .pin_dout_in   (pin_dout_stb_in),
   .pin_dout_out  (pin_dout_stb_out),
   .pin_din_in    (pin_din_stb_in),
   .pin_din_out   (pin_din_stb_out),
   .pin_wtbt      (wtbt),
	.pin_rmw       (rmw),
   .pin_ctrl_ena  (),

   .pin_sync_in   (pin_sync),
   .pin_sync_out  (pin_sync),
   .pin_sync_ena  (),

   .pin_rply_in   (pin_rply | rply),
   .pin_rply_out  (rply),

   .pin_pa        (0),

   .pin_dmr_in    (pin_dmr),
   .pin_dmr_out   (),
   .pin_sack_in   (pin_sack),
   .pin_sack_out  (),

   .pin_dmgi      (0),
   .pin_dmgo      (pin_dmgo),
   .pin_iako      (pin_iako),
   .pin_sp        (0),
   .pin_sel       (pin_sel),
   .pin_bsy       (pin_bsy)
);
endmodule


////////////////////////////////////////////////////////////////////////////////
// 
// Reset module
//

module vm1_reset
(
	input      clk,
	input      reset,
	output reg dclo,
	output reg aclo
);

parameter  DCLO_WIDTH = 140000;   //  >5ms for 27MHz
parameter  ACLO_WIDTH = 1900000;  // >70ms for 27MHz

always @(posedge clk) begin
	integer cnt;
	
	if(reset) begin
		cnt  <= 0;
		aclo <= 1;
		dclo <= 1;
	end else begin
		if(dclo | aclo) begin
			cnt <= cnt + 1;
			if(cnt > DCLO_WIDTH) dclo <= 0;
			if(cnt > ACLO_WIDTH) aclo <= 0;
		end
	end
end

endmodule
