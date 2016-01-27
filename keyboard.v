

module keyboard_wb
(
	input				wb_clk,
	input	 [15:0]	wb_adr,
	input	 [15:0]	wb_dat_i,
   output [15:0]	wb_dat_o,
	input				wb_cyc,
	input	  			wb_we,
	input	  [1:0]	wb_sel,
	input				wb_stb,
	output			wb_ack,

	output			virq_req60,
	input				virq_ack60,
	output			virq_req274,
	input				virq_ack274,

	input          sys_init,
	input          PS2_CLK,
	input          PS2_DAT,
	output         key_down,
	output         key_stop
);

wire [1:0] ena;
reg  [1:0] ack;

reg [15:0] reg660 = 16'b1000000;
reg [15:0] reg662 = 16'd0;

reg [15:0] data_o;
assign wb_dat_o = (valid && !wb_we) ? data_o : 16'd0;

wire sel660 = wb_cyc && (wb_adr[15:1] == (16'o177660 >> 1));
wire sel662 = wb_cyc && ((wb_adr[15:1] == (16'o177662 >> 1)) && !wb_we); //Read-only
wire stb660 = wb_stb && sel660;
wire stb662 = wb_stb && sel662;

wire valid  = sel660 | sel662;

assign wb_ack = wb_stb & valid & (ack[1] | wb_we);
always @ (posedge wb_clk) begin
	ack[0] <= wb_stb & valid;
	ack[1] <= wb_cyc & ack[0];
end

reg req60, req274;
assign virq_req60 = req60;
assign virq_req274 = req274;

assign key_down = (saved_key != 8'd0);
assign key_stop = (state_stop != 8'd0);

reg        pressed;
reg        e0;
reg        state_shift;
reg        state_alt;
reg        state_ctrl;
reg  [6:0] state_caps;
reg  [6:0] state_rus;
reg  [7:0] state_stop;
reg  [7:0] saved_key;

wire [6:0] decoded;
wire       autoar2;
wire [7:0] keyb_data;
wire       keyb_valid;

// PS/2 interface
ps2_intf ps2(
	wb_clk,
	!sys_init,
		
	PS2_CLK,
	PS2_DAT,

	// Byte-wide data interface - only valid for one clock
	// so must be latched externally if required
	keyb_data,
	keyb_valid
);

kbd_transl kbd_transl( .shift(state_shift), .e0(e0), .incode(keyb_data), .outcode(decoded), .autoar2(autoar2)); 

wire lowercase = (decoded > 7'h60) & (decoded <= 7'h7a); 
wire uppercase = (decoded > 7'h40) & (decoded <= 7'h5a);

wire [6:0] ascii = state_ctrl ? {2'b00, decoded[4:0]} : 
                    lowercase ? decoded - (state_rus ^ state_caps) : 
                    uppercase ? decoded + (state_rus ^ state_caps) : decoded; 

always @(posedge sys_init or posedge wb_clk) begin
	reg old_stb660, old_stb662, old_ack60, old_ack274;
	
	if(sys_init) begin
		pressed     <= 1'b1;
		e0          <= 1'b0;
		state_stop  <= 8'd0;
		state_caps  <= 7'h00;
		state_shift <= 1'b0;
		state_alt   <= 1'b0;
		state_ctrl  <= 1'b0;
		state_rus   <= 7'h20;
		saved_key   <= 8'd0;
		reg660[6]   <= 1'b1;
		reg660[7]   <= 1'b0;
		req60       <= 1'b0;
		req274      <= 1'b0;
	end else begin
		if(state_stop != 8'd0) state_stop <= state_stop - 8'd1;

		old_stb660 <= stb660;
		if(!old_stb660 && stb660) begin
			if(wb_we) reg660[6] <= wb_dat_i[6];
				else data_o <= reg660;
		end

		old_stb662 <= stb662;
		if(!old_stb662 && stb662) begin
			data_o <= reg662;
			reg660[7] <= 1'b0;
			req274 <= 1'b0;
			req60  <= 1'b0;
		end 

		old_ack60 <= virq_ack60;
		if(!old_ack60 && virq_ack60) req60 <= 1'b0;

		old_ack274 <= virq_ack274;
		if(!old_ack274 && virq_ack274) req274 <= 1'b0;
		
		if (keyb_valid) begin
			if (keyb_data == 8'HE0)
				e0 <=1'b1;
			else if (keyb_data == 8'HF0)
				pressed <= 1'b0;
			else begin
				case({e0, keyb_data})
					9'H058: if(pressed) state_caps <= state_caps ^ 7'h20;
					9'H059: state_shift <= pressed;
					9'H012: state_shift <= pressed;
					9'H011: state_alt   <= pressed;
					9'H014: state_ctrl  <= pressed;
					8'h009: if(pressed) state_stop <= 8'd40;
					9'H007: ; // disable F12 handling
					default: begin

						if(decoded == 7'o016)      state_rus <= 7'h00; 
						else if(decoded == 7'o017) state_rus <= 7'h20;

						if(pressed) begin
							if(!saved_key) begin
								saved_key <= keyb_data;
								if(!reg660[7] && (ascii != 7'd0)) begin
									reg662[6:0] <= ascii;
									reg660[7]   <= 1'b1;
								
									if(!reg660[6]) begin
										if(state_alt | autoar2) req274 <= 1'b1;
											else  req60 <= 1'b1;
									end
								end
							end
						end else if(saved_key == keyb_data) saved_key <= 8'd0;
					end
				endcase;

				pressed <= 1'b1;
				e0 <= 1'b0;
         end 
      end 
   end 
end	

endmodule
