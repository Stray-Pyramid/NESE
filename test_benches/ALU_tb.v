module ALU_tb ();

reg SUM_en, AND_en, EOR_en, OR_en, ASL_en, LSR_en, INV_en, ROL_en, ROR_en; // Operation control
reg [7:0] Ain, Bin;	// Data inputs
reg Cin = 1'b0; 			 	// Carry in
wire [7:0] RES;		// Operation result
wire Cout; 				// Carry out
wire OVFout;

initial begin
	SUM_en = 1'b0;
	AND_en = 1'b0;
	EOR_en = 1'b0;
	OR_en = 1'b0;
	ASL_en = 1'b0;
	LSR_en = 1'b0;
	INV_en = 1'b0;
	ROL_en = 1'b0;
	ROR_en = 1'b0;

	Ain = 8'd0;
	Bin = 8'd0;
	
	Cin = 1'b1;
	Ain = 8'b10101010;
	
	ASL_en = 1'b1;
	
	#10
	
	ASL_en = 1'b0;
	LSR_en = 1'b1;
	
	#10
	
	LSR_en = 1'b0;
	ROL_en = 1'b1;
	
	#10
	
	ROL_en = 1'b0;
	ROR_en = 1'b1;
	
	#10;

end



ALU UUT
(
	.SUM_en(SUM_en),
	.AND_en(AND_en),
	.EOR_en(EOR_en),
	.OR_en(OR_en),
	.ASL_en(ASL_en),
	.LSR_en(LSR_en),
	.INV_en(INV_en),
	.ROL_en(ROL_en),
	.ROR_en(ROR_en),
   .Ain(Ain),
	.Bin(Bin), 
   .Cin(Cin), 	
   .RES(RES),		
   .Cout(Cout), 
   .OVFout(OVFout)
);


endmodule
