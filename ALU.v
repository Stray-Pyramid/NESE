module ALU(  
	input wire SUM_en, AND_en, EOR_en, OR_en, LSR_en, ASL_en, INV_en, ROL_en, ROR_en, // Operation control
	input wire [7:0] Ain, Bin, 					     // Data inputs
	input wire Cin, 						     	  // Carry in
	output reg [7:0] RES,					     // Operation result
	output reg Cout, 						     // Carry out
	output wire OVFout						     // Overflow out
	);

	// Declare signals:
	wire [7:0] Bint;
	wire Cint;
	
	
    // Select inverted or non-inverted B input:
	assign Bint = (INV_en) ? ~Bin : Bin;
    
    // Perform requested operation:
	always @(*) begin
		
		// Defaults:
		RES = 0;
		Cout = 0;
			
		// Operations:
		if (SUM_en)
			{Cout, RES} = Ain + Bint + Cin;	// add with carry-in, carry-out
		else if (AND_en)
			RES = Ain & Bin;	// and
		else if (EOR_en)
			RES = Ain ^ Bin;	// xor
		else if (OR_en)
			RES = Ain | Bin;	// or
		else if (LSR_en)
			{RES, Cout} = {Ain,1'd0} >> 1;  // shift right with carry-out
		else if (ASL_en)
			{Cout, RES} = {1'd0, Ain} << 1; // shift left with carry-out
		else if (ROL_en)
			{Cout, RES} = {Ain, Cin};  // shift left with carry-in, carry-out
		else if (ROR_en)
			{RES, Cout} = {Cin,Ain};	// shift right with carry-in, carry-out
	
	end
	
	// Set overflow flag (set if both inputs are same sign, but output is a different sign):
	assign OVFout = (Ain[7] && Bint[7] && (!RES[7])) || ((!Ain[7]) && (!Bint[7]) && RES[7]);
	 
	
	 
endmodule
