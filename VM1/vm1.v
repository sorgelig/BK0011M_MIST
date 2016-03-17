
module vm1
(
   input         pin_clk,     // processor clock
   input         pin_dclo,    // processor reset
   input         pin_aclo,    // power fail notoficaton
   output        pin_init,    // peripheral reset

   input   [3:1] pin_irq,     // radial interrupt requests
   input         pin_virq,    // vectored interrupt request
   output        pin_iako,    // interrupt vector input
	
   input         pin_dmr,
   output        pin_dmgo,
   input         pin_sack,

   output [15:0] pin_addr,    // address bus
   output [15:0] pin_dout,    // data out bus
   input  [15:0] pin_din,     // data in bus
   output        pin_sync,    // address strobe
   output        pin_we,      // write data
   input         pin_din_in,
   output        pin_din_out,
   input         pin_dout_in,
   output        pin_dout_out,
   output  [1:0] pin_wtbt,    // write/byte status
   input         pin_rply,    // transaction reply
   output        pin_bsy,     // bus busy flag
	
   output  [2:1] pin_sel      // register select outputs
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
	old_din <= pin_din_out;
	
	if(!old_sync & pin_sync) begin
		addr  <= pin_dout;
		write <= wtbt;
		rmw_mode <= rmw;
	end

	if(old_din & !pin_din_out & rmw_mode & pin_sync) write <= 1; //Next is write for RMW.
	if(old_sync & !pin_sync) write <= 0;
end

vm1_qbus core
(
   .pin_clk_p     (pin_clk),
   .pin_clk_n     (~pin_clk),
   .pin_ena       (1),
   .pin_init_in   (0),
   .pin_init_out  (pin_init),
   .pin_dclo      (pin_dclo),
   .pin_aclo      (pin_aclo),
   .pin_irq       (pin_irq),
   .pin_virq      (pin_virq),

   .pin_ad_in     (pin_din_out ? pin_din : pin_dout),
   .pin_ad_out    (pin_dout),

   .pin_dout_in   (pin_dout_in),
   .pin_dout_out  (pin_dout_out),
   .pin_din_in    (pin_din_in),
   .pin_din_out   (pin_din_out),
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
