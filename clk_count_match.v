module clk_count_match (
	input clk_in,
	input active,
	input reset,
	
	input [63:0] trg_count,
	
	output wire clk_out,
	output wire match

);

reg [63:0] act_count = 64'd0;

assign match = act_count == trg_count;
assign clk_out = (!active || (match && active)) ? 1'b0 : clk_in;


always @(negedge clk_in)
begin
	if(reset) begin
		act_count <= 64'd0;
	end else if(active && act_count != trg_count)
		// act_count will only increment if active is high.
		// Count should stop if target is met.
		// If user extends trg_count by another 50 clock cycles
		// they should expect it to run another 50 clock cycles.
		act_count <= act_count + 1'b1;

end

endmodule
