task ADC();
	// Add Memory to Accumulator with Carry (A + M + C -> A,C) [N,Z,C,V]
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	SUM_en <= 1'b1;
	ALU_CIN <= STAT[0];
	ACC_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
	UPDATE_OVF <= 1'b1;
endtask

task AND();
	// AND Memory with Accumulator (A AND M -> A) [N,Z]
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	AND_en <= 1'b1;
	ACC_SAVE <= 1'b1;
	
	// STAT bits for AND opcode are set a cycle early
	STAT[1] <= (ACC & D_BUS) == 0 ? 1'b1 : 1'b0; // Z
	STAT[7] <= (ACC[7] & D_BUS[7]); // N
endtask

task ASL_A();
	// Shift Left One Bit (Accumulator)
	ALU_A <= ACC;
	ASL_en <= 1'b1;
	
	ACC_SAVE <= 1'b1;
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task ASL();
	// Shift Left One Bit (Memory)
	ALU_A <= D_BUS;
	ASL_en <= 1'b1;
		
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task BPL();
	// Branch on Plus
	decide_branch(!STAT[7]);
endtask

task BMI();
	// Branch on Minus / Negative
	decide_branch(STAT[7]);
endtask

task BVC();
	// Branch on Overflow Clear
	decide_branch(!STAT[6]);
endtask

task BVS();
	// Branch on Overflow Set
	decide_branch(STAT[6]);
endtask

task BCC();
	// Branch on Carry Clear
	decide_branch(!STAT[0]);
endtask

task BCS();
	// Branch on Carry Set
	decide_branch(STAT[0]);
endtask

task BNE();
	// Branch on Not Equal
	// Uses Zero Flag
	decide_branch(!STAT[1]);
endtask

task BEQ();
	// Branch on Equal
	// Uses Zero Flag
	decide_branch(STAT[1]);
endtask

task BIT();
	// Test Bits in Memory with Accumulator (A AND M, M7 - N, M6 -> V)[N,Z,V]
	STAT[7] <= D_BUS[7];
	STAT[6] <= D_BUS[6];
	
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	AND_en <= 1'b1;
	
	UPDATE_Z <= 1'b1;
endtask

task BRK();
	// Force Break
	case(I_C)
		4'd0: begin
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
		end
		4'd1: begin
			// Write PCH to stack
			increment_pc();
			DB_WRITE <= (PCL == 8'hFF) ? (PCH + 1) : PCH; // Account for page crossing
			RW <= 0;
			A_BUS <= {8'h01, SP};
			ABL_HOLD <= SP - 1;
			I_C <= I_C + 1;
		end
		4'd2: begin
			// Write PCL to stack
			A_BUS <= {8'h01, ABL_HOLD};
			ABL_HOLD <= ABL_HOLD - 1;
			DB_WRITE <= PCL;
			I_C <= I_C + 1;
		end
		4'd3: begin
			// Write status register to stack with B flag set
			A_BUS <= {8'h01, ABL_HOLD};
			ABL_HOLD <= ABL_HOLD - 1;
			
			
			DB_WRITE <= {STAT[7:6], 2'b11, STAT[3:0]};
			
			
			I_C <= I_C + 1;
		end
		4'd4: begin
			// Finish writing, update stack pointer
			A_BUS <= 16'hFFFE;
			RW <= 1'b1;
			SP <= A_BUS[7:0] - 1;
			I_C <= I_C + 1;
		end
		4'd5: begin
			// Fetch interrupt PCL
			A_BUS <= 16'hFFFF;
			ABL_HOLD <= DB_READ;
			I_C <= I_C + 1;
		end
		4'd6: begin
			// Fetch interrupt PCH, update PC
			A_BUS <= {DB_READ, ABL_HOLD};
			PCL <= ABL_HOLD;
			PCH <= DB_READ;
			next_instruction();
		end
	endcase
endtask

task CLC(); 
	// Clear Carry Flag (0 -> C)[C]
	STAT[0] <= 0;
endtask

// The RP2A03 chip lacks the 6502's decimal mode
task CLD(); 
	// Clear Decimal Mode
	STAT[3] <= 1'b0;
endtask

task CLI();
	// Clear Interrupt Disable Bit (0 -> I)[I]
	STAT[2] <= 0;
endtask

task CLV();
	// Clear Overflow Flag (0 -> V)[V]
	STAT[6] <= 0;
endtask

task CMP();
	// Compare Memory with Accumulator (A - M)[N,Z,C]
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	SUM_en <= 1'b1;
	INV_en <= 1'b1;
	ALU_CIN <= 1'b1;
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
	
endtask

task CPX();
	// Compare Memory and Index X (X - M)[N,Z,C]
	ALU_A <= X;
	ALU_B <= D_BUS;
	SUM_en <= 1'b1;
	INV_en <= 1'b1;
	ALU_CIN <= 1'b1;
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task CPY();
	// Compare Memory and Index Y (Y - M)[N,Z,C]
	ALU_A <= Y;
	ALU_B <= D_BUS;
	SUM_en <= 1'b1;
	INV_en <= 1'b1;
	ALU_CIN <= 1'b1;
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task DEC();
	// Decrement Memory by One (M - 1 -> M)[N,Z]
	ALU_A <= D_BUS;
	ALU_B <= 8'd1;
	
	SUM_en <= 1'b1;
	INV_en <= 1'b1;
	ALU_CIN <= 1'b1;
	
	UPDATE_NZ <= 1'b1;
	
endtask

task DEX();
	// Decrement Index Y by One (X - 1 -> X)[N,Z]
	ALU_A <= X - 1'd1;
	ALU_B <= 8'd0;
	OR_en <= 1'b1;
	X_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
endtask

task DEY();
	// Decrement Index Y by One (Y - 1 -> Y)[N,Z]
	ALU_A <= Y - 1'd1;
	ALU_B <= 8'd0;
	OR_en <= 1'b1;
	Y_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
endtask

task EOR();
	// Exclusive-OR Memory with Accumulator (A EOR M -> A) [N,Z]	
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	EOR_en <= 1'b1;
	ACC_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
endtask

task INC();
	// Increment Memory by One (M + 1 -> M)[N,Z]
	ALU_A <= D_BUS;
	ALU_B <= 8'd1;
	
	SUM_en <= 1'b1;
	ALU_CIN <= 1'b0;
	
	UPDATE_NZ <= 1'b1;
	
endtask

task INX();
	// Increment Index X by One (X + 1 -> X)[N,Z]
	ALU_A <= X + 1'd1;
	ALU_B <= 8'd0;
	OR_en <= 1'b1;
	X_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
endtask

task INY();
	// Increment Index Y by One (Y + 1 -> Y)[N,Z]
	ALU_A <= Y + 1'd1;
	ALU_B <= 8'd0;
	OR_en <= 1'b1;
	Y_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
endtask

task JMP();
	// Jump to New Location
	case(I_C)
		4'd0: begin
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
		end
		4'd1: begin
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
			
			ABL_HOLD <= D_BUS;
		end
		4'd2: begin
			A_BUS <= {D_BUS, ABL_HOLD};
			PCL <= ABL_HOLD;
			PCH <= D_BUS;
			if (OP_CODE == 8'h4C) begin
				// abs
				next_instruction();
			end else begin
				// (ind)
				I_C <= I_C + 1;
			end
		end
		4'd3: begin
			ABL_HOLD <= D_BUS;
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
		end
		4'd4: begin
			PCL <= ABL_HOLD;
			PCH <= D_BUS;
			A_BUS <= {D_BUS, ABL_HOLD};
			next_instruction();
		end
	endcase
endtask

task JSR();
	// Jump to New Location Saving Return Address
	case(I_C)
		4'd0: begin
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
		end
		4'd1: begin
			increment_pc();
			A_BUS <= {8'h01, SP};
			SP <= D_BUS;
			I_C <= I_C + 1;
		end
		4'd2: begin
			RW <= 0;
			DB_WRITE <= PCH;
			I_C <= I_C + 1;
		end
		4'd3: begin
			A_BUS <= A_BUS - 1;
			DB_WRITE <= PCL;
			I_C <= I_C + 1;
		end
		4'd4: begin
			RW <= 1'b1;
			A_BUS <= PC;
			ABL_HOLD <= A_BUS[7:0];
			I_C <= I_C + 1;
		end
		4'd5: begin
			A_BUS <= {D_BUS, SP};
			PCH <= D_BUS;
			PCL <= SP;
			SP <= ABL_HOLD - 1'b1;
			next_instruction();
		end
	endcase
endtask

task LDX();
	// Load Index X with Memory (M -> X) [N,Z]
	X <= D_BUS;
	update_nz_flags(D_BUS);
endtask
	
task LDY();
	// Load Index Y with Memory (M -> Y) [N,Z]
	Y <= D_BUS;
	update_nz_flags(D_BUS);
endtask

task LDA();
	// Load Accumulator with Memory (M -> A) [N,Z]
	ACC <= D_BUS;
	update_nz_flags(D_BUS);
endtask

task LSR_A();
	//Shift One Bit Right (Accumulator)[N=0,Z,C]
	ALU_A <= ACC;
	LSR_en <= 1'b1;
	
	ACC_SAVE	<= 1'b1;
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task LSR();
	// Shift One Bit Right (Memory)[N=0,Z,C]
	ALU_A <= DB_READ;
	LSR_en <= 1'b1;
		
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task NOP(); 
	// No Operation
	;
endtask

task ORA();
	// OR Memory with Accumulator (A OR M -> A) [N,Z] 
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	OR_en <= 1'b1;
	ACC_SAVE <= 1'b1;
	UPDATE_NZ <= 1'b1;
endtask

task PHA();
	// Push Accumulator on Stack
	if(I_C == 4'd1) begin
		A_BUS <= {8'b1, SP};
		DB_WRITE <= ACC;
		RW <= 0;
	end else if (I_C == 4'd2) begin
		SP <= SP - 1'd1;
		RW <= 1;
		A_BUS <= PC;
	end
endtask

task PHP();
	// Push Processor Status on Stack
	if(I_C == 1) begin
		A_BUS <= {8'b1, SP};
		DB_WRITE <= {STAT[7:6], 2'b11, STAT[3:0]};
		RW <= 0;
	end else if (I_C == 2) begin
		SP <= SP - 1'd1;
		RW <= 1;
		A_BUS <= PC;
	end
endtask
			
task PLA();
	// Pull Accumulator from Stack [N,Z]
	if(I_C == 1) begin
		A_BUS <= {8'b1, SP};
	end else if (I_C == 2) begin
		A_BUS <= A_BUS + 1'd1;
		SP <= SP + 1'd1;
	end else if (I_C == 3) begin
		ACC <= D_BUS;
		A_BUS <= PC;
		update_nz_flags(D_BUS);
	end
endtask	
	
task PLP();	// Pull Processor Status from Stack [N,Z,C,I,D,V]
	if(I_C == 1) begin
		A_BUS <= {8'b1, SP};
	end else if (I_C == 2) begin
		A_BUS <= A_BUS + 1'd1;
		SP <= SP + 1'd1;
	end else if (I_C == 3) begin

		STAT <= {D_BUS[7:6], STAT[5:4], D_BUS[3:0]};
		A_BUS <= PC;
	end
endtask

task ROL_A();
	// Rotate One Bit Left (Accumulator)[N,Z,C]
	ALU_A <= ACC;
	ROL_en <= 1'b1;
	
	ACC_SAVE <= 1'b1;
	
	ALU_CIN <= STAT[0];

	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task ROL();
	// Rotate One Bit Left (Memory)[N,Z,C]
	ALU_A <= DB_READ;
	ROL_en <= 1'b1;
	
	ALU_CIN <= STAT[0];

	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task ROR_A();
	// Rotate One Bit Right (Accumulator)[N,Z,C]
	ALU_A <= ACC;
	ROR_en <= 1'b1;
	
	ACC_SAVE <= 1'b1;
		
	ALU_CIN <= STAT[0];
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task ROR();
	// Rotate One Bit Right (Memory)[N,Z,C]
	ALU_A <= DB_READ;
	ROR_en <= 1'b1;
		
	ALU_CIN <= STAT[0];
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
endtask

task RTI();
	// Return from Interrupt [N,Z,C,I,D,V]
	// UNTESTED
	case(I_C)
		4'd0: begin
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
		end
		4'd1: begin
			A_BUS <= {8'h01, SP};
			ABL_HOLD <= SP + 1;
			I_C <= I_C + 1;
		end
		4'd2: begin
			A_BUS <= {8'h01, ABL_HOLD};
			ABL_HOLD <= ABL_HOLD + 1;
			I_C <= I_C + 1;
		end
		4'd3: begin
			A_BUS <= {8'h01, ABL_HOLD};
			ABL_HOLD <= ABL_HOLD + 1;
			I_C <= I_C + 1;
			STAT <= {DB_READ[7:6], 1'b0, DB_READ[4:0]}; // Clear 5th bit
		end
		4'd4: begin
			A_BUS <= {8'h01, ABL_HOLD};
			SP <= ABL_HOLD;
			ABL_HOLD <= DB_READ;
			I_C <= I_C + 1;
		end
		4'd5: begin
			A_BUS <= {DB_READ, ABL_HOLD};
			PCL <= ABL_HOLD;
			PCH <= DB_READ;
			next_instruction();
		end
	endcase
endtask

task RTS();
	// Return from Subroutine
	case(I_C)
		4'd0: begin
			increment_pc();
			A_BUS <= PC + 1;
			I_C <= I_C + 1;
		end
		4'd1: begin
			increment_pc();
			A_BUS <= {01, SP};
			I_C <= I_C + 1;
		end
		4'd2: begin
			ABL_HOLD <= D_BUS;
			A_BUS <= A_BUS + 1;
			I_C <= I_C + 1;
		end
		4'd3: begin
			A_BUS <= A_BUS + 1;
			SP <= A_BUS[7:0] + 1;
			PCL <= D_BUS;
			I_C <= I_C + 1;
		end
		4'd4: begin
			PCH <= D_BUS;
			A_BUS <= {D_BUS, PCL};
			I_C <= I_C + 1;
		end
		4'd5: begin
			A_BUS <= PC + 1;
			increment_pc();
			next_instruction();
		end
	endcase
endtask

task SBC();
	// Subtract Memory from Accumulator with Borrow (A - M - !C -> A) [N,Z,C,V]
	ALU_A <= ACC;
	ALU_B <= D_BUS;
	SUM_en <= 1'b1;
	INV_en <= 1'b1;
	ACC_SAVE <= 1'b1;
	ALU_CIN <= STAT[0];
	
	UPDATE_NZ <= 1'b1;
	UPDATE_CARRY <= 1'b1;
	UPDATE_OVF <= 1'b1;
endtask

task SEC();
	// Set Carry Flag (1 -> C)[C]
	STAT[0] <= 1;
endtask

task SED(); 
	// Set Decimal Mode
	STAT[3] <= 1'b1;
endtask

task SEI();
	// Set Interrupt Disable Status (1 -> I)[I]
	STAT[2] <= 1;
endtask

task STA();
	// Store Accumulator in Memory
	DB_WRITE <= ACC;
endtask

task STX();
	// Store Index X in Memory
	DB_WRITE <= X;
endtask

task STY();
	// Store Index Y in Memory
	DB_WRITE <= Y;
endtask

task TAY();
	// Transfer Accumulator to Index Y (A -> Y)[N,Z]
	Y <= ACC;
	update_nz_flags(ACC);
endtask

task TXA();
	// Transfer Index X to Accumulator (X -> A)[N,Z]
	ACC <= X;
	update_nz_flags(X);
endtask

task TAX();
	// Transfer Accumulator to Index X (A -> Y)[N,Z]
	X <= ACC;
	update_nz_flags(ACC);
endtask
	
task TSX();
	// Transfer Stack Pointer to Index X (SP -> X)[N,Z]
	X <= SP;
	update_nz_flags(SP);
endtask

task TXS();
	// Transfer Index X to Stack Register (X -> SP)
	SP <= X;
	update_nz_flags(X);
endtask

task TYA();
	// Transfer Index Y to Accumulator (Y -> A)[N,Z]
	ACC <= Y;
	update_nz_flags(Y);
endtask
