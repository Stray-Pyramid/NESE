module falling_edge_detector (
	input trigger,
	input clear,
	
	output reg out
);

reg clear_lockout = 1'b0;
reg trigger_lockout = 1'b0;

initial out = 1'b0;

// Out will go high on falling edge of trigger, no matter what state clear is in.
// Clear will only clear out on a rising edge.
// If trigger and clear happen, trigger will take priority, and out will go/stay high.
always @(trigger, clear) begin
		
	if(clear && !clear_lockout) begin
		out = 1'b0;
		clear_lockout = 1'b1;
	end else if(!clear)
		clear_lockout = 1'b0;
		
	if(!trigger && !trigger_lockout) begin
		out = 1'b1;
		trigger_lockout = 1'b1;
	end else if(trigger)
		trigger_lockout = 1'b0;
		
end

endmodule
