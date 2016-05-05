////////////////////////////////////////////////////////////////////////////////
//
//
//
//  PS2 Mouse for MIST
//  (C) 2015 Sorgelig
//
//
//
////////////////////////////////////////////////////////////////////////////////

module ps2_mouse (
	input            clk,
	input            ps2_clk,
	input            ps2_data,
	output reg       left_btn,
	output reg       right_btn,
	output reg [8:0] pointer_dx,
	output reg [8:0] pointer_dy,
	output reg       data_ready,
	output reg [7:0] counter
);

reg [32:0] q;  // Shift register
reg [5:0] bcount=6'd0;
integer   idle = 0;


always @(posedge clk) begin
	reg old_ps2_clk;
	old_ps2_clk <= ps2_clk;
	data_ready <= 1'b0;

	if(old_ps2_clk && !ps2_clk) begin
		q[bcount]  <= ps2_data;
	end else if(!old_ps2_clk && ps2_clk) begin
		bcount <= bcount + 1'b1;
		if(bcount == 6'd32) begin
			bcount <=0;
			if((q[0]  == 0) && (q[10] == 1) && (q[11] == 0) && (q[21] == 1) && (q[22] == 0) && (q[32] == 1)
				&& (q[9]  == ~^q[8:1]) && (q[20] == ~^q[19:12]) && (q[31] == ~^q[30:23]) )
			begin
				data_ready <= 1'b1;
				left_btn   <= q[1];
				right_btn  <= q[2];
				pointer_dx <= {q[5],q[19:12]};
				pointer_dy <= {q[6],q[30:23]};
				counter <= counter + 1'b1;
			end
		end
		idle <= 0;
	end else if(ps2_clk) idle <= idle + 1;
	if(idle > 384000000) begin // 4 second to reset the bit counter.
		idle   <= 0;
		bcount <= 0;
	end
end

endmodule

