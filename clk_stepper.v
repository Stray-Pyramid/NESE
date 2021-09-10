module clk_stepper (

	input clk_in,
	input active,
	input step,
	
	output clk_out

);

reg step_lock;

assign clk_out = (!active && clk_in) || (step_lock && clk_in) ? 1'b1 : 1'b0;

always @(negedge clk_in) begin

	if(step && active) begin
		step_lock <= 1'b1;	
	end else
		step_lock <= 1'b0;

end 

endmodule
