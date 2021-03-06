// CPU_6502.v
// 
// TODO
// - Test NMI, IRQ and RTI functionality

module CPU_6502(

	input clk,
	input rst_n,

	inout [7:0] D_BUS,  // Data pins
	output reg [15:0] A_BUS, // Address pins
	
	// Not needed, since we have fine control over the clock signal
	// and the 6502 variant used for the NES does not have a RDY pin
	//input RDY 

	// Interrupts
	input IRQ,
	input NMI,

	output reg RW,
	output reg SYNC,
	
	// Debug wires
	output [15:0] PC_DBG, 
	output [7:0] X_DBG,
	output [7:0] Y_DBG, 
	output [7:0] ACC_DBG, 
	output [7:0] STAT_DBG, 
	output [7:0] SP_DBG,
	output [7:0] OP_CODE_DBG, 
	output [2:0] I_C_DBG
	
);

//initial RW = 1'b1;
//initial SYNC = 1'b0;

wire [7:0] DB_READ;
reg [7:0] DB_WRITE;

// RW pin low, CPU controls data bus
assign D_BUS = ~RW ? DB_WRITE : 8'hZZ;
assign DB_READ = D_BUS;

// Program Counter
reg [7:0] PCH;
reg [7:0] PCL;
wire [15:0] PC;
assign PC = {PCH, PCL};

// Registers
reg [7:0] X = 8'b0;
reg [7:0] Y = 8'b0;
reg [7:0] ACC = 8'b0;

reg X_SAVE, Y_SAVE, ACC_SAVE = 1'b0;

reg [7:0] SP = 8'hFD;   // Stack Pointer
reg [7:0] STAT = 8'h16; // Status Register
reg UPDATE_NZ = 1'b0;
reg UPDATE_Z = 1'b0;
reg UPDATE_CARRY = 1'b0;
reg UPDATE_OVF = 1'b0;

// Instruction Tick
reg [2:0] I_C = 3'b0;

// A_BUS Address Hold
reg [7:0] ABL_HOLD = 8'b0;

// CPU STATE
localparam S_STARTUP = 1'b0;
localparam S_RUNNING = 1'b1;
reg CPU_STATE = S_STARTUP;

// OP_CODE Instruction Register
reg [7:0] OP_CODE;
wire [2:0] OP_HIGH;
wire [2:0] OP_MID;
wire [1:0] OP_LOW;

assign OP_HIGH = OP_CODE[7:5];
assign OP_MID = OP_CODE[4:2];
assign OP_LOW = OP_CODE[1:0];

// ALU
reg SUM_en, AND_en, EOR_en, OR_en, ASL_en, LSR_en, INV_en, ROL_en, ROR_en, CMP_en;
reg ALU_CIN;
reg [7:0] ALU_A;
reg [7:0] ALU_B;
wire [7:0] ALU_OUT;
wire ALU_COUT, ALU_OVERFLOW;

// Interrupts
localparam NO_INT = 2'b00;
localparam NMI_INT = 2'b01;
localparam IRQ_INT = 2'b10;

wire NMI_TRIGGERED;
reg NMI_RESET = 1'b0;
reg [1:0] INTERRUPT_TYPE = NO_INT;

// Debug Wire Assignments
assign PC_DBG = PC;
assign X_DBG = X;
assign Y_DBG = Y;
assign ACC_DBG = ACC;
assign STAT_DBG = STAT;
assign SP_DBG = SP;
assign OP_CODE_DBG = OP_CODE;
assign I_C_DBG = I_C;

// Instruction logic
`include "instructions.v"

always @(posedge clk) begin
	
	if(!rst_n) begin
		cpu_reset();
	end
//	else if (!clk) begin
//		// Next instruction and interrupt handling
//		
//		if(I_C == 0) begin
//		// On a new instruction...
//	
//			if (NMI_TRIGGERED) begin
//				NMI_RESET <= 1'b1; // Acknowledge the NMI
//				OP_CODE <= 8'h00; // BRK
//				 <= NMI_INT;
//				STAT[2] <= 1'b1; // Disable further IRQs
//			
//			end else if (IRQ == 1'b0 && STAT[2] == 1'b0) begin
//				OP_CODE <= 8'h00; // BRK
//				INTERRUPT_TYPE <= IRQ_INT;
//				STAT[2] <= 1'b1; // Disable further IRQs
//				
//			end 
//		
//		end else begin
//			// Next instruction should be the one on the DataBus
//			OP_CODE <= DB_READ;
//			INTERRUPT_TYPE <= NO_INT;
//		end
		
	else if (clk) begin
	
		if (CPU_STATE == S_STARTUP) begin
			// In startup, fetch the reset vector,
			case(I_C)
				4'd0: begin
					A_BUS <= 16'hFFFC;
					I_C <= I_C + 1'd1;
				end
				4'd1: begin
					PCL <= DB_READ;
					A_BUS <= 16'hFFFD;
					I_C <= I_C + 1'd1;
				end
				4'd2: begin
					PCH <= DB_READ;
					A_BUS <= {DB_READ, PCL};
					CPU_STATE <= S_RUNNING;
					next_instruction();

				end
			endcase
		
		end else if (CPU_STATE == S_RUNNING) begin
			// Reload the NMI falling-edge detector			
			if (RW)
					DB_WRITE <= DB_READ;
			else
				;
			
			if(I_C == 4'b0) begin					
				// At the beginning of every instruction					
				
				SYNC <= 1'b0;
				alu_reset();
								
				// To mimic the behaviour of the 6502, 
				// ALU results are delayed by one clock cycle
				save_alu_result();
				update_flags();
				
				// No matter what instruction, the following always happens
				increment_pc();
				A_BUS <= PC + 1'b1;
				I_C <= I_C + 1'b1;
				
				// Interrupt
				if (NMI_TRIGGERED) begin
					NMI_RESET <= 1'b1; // Acknowledge the NMI
					OP_CODE <= 8'h00; // BRK
					INTERRUPT_TYPE <= NMI_INT;
					STAT[2] <= 1'b1; // Disable further IRQs
			
				end else if (IRQ == 1'b0 && STAT[2] == 1'b0) begin
					OP_CODE <= 8'h00; // BRK
					INTERRUPT_TYPE <= IRQ_INT;
					STAT[2] <= 1'b1; // Disable further IRQs
					
				// No interrupt, continue as normal
				end else
					OP_CODE <= D_BUS;
				
			end else
				do_instruction();
		end
	end
end

task do_instruction;
	// OPCODES are organized into addressing mode
	// with the exception of unique opcodes
	if (OP_CODE == 8'h00) begin
		BRK();
	end else if (OP_CODE == 8'h20) begin
		JSR();
	end else if (OP_CODE == 8'h40) begin
		RTI();
	end else if (OP_CODE == 8'h60) begin
		RTS();
	end else if (OP_CODE == 8'h4C || OP_CODE == 8'h6C) begin
		JMP(); // abs & (ind)
	end
	
	else
				
	// IMPLIED INSTRUCTIONS
	if ((OP_MID == 3'd2 && OP_LOW == 2'd0) ||
		 (OP_MID == 3'd2 && OP_LOW == 2'd2) ||
		 (OP_MID == 3'd6 && OP_LOW == 2'd0) ||
		 (OP_MID == 3'd6 && OP_LOW == 2'd2 && (OP_HIGH == 3'd4 || OP_HIGH == 3'd5)))
	begin
		handle_implied();
	end
	
	else
	
	// IMMEDIATE INSTRUCTIONS
	if ((OP_MID == 3'd0 && OP_LOW == 2'd0 && OP_HIGH >= 3'd5) ||
		 (OP_MID == 3'd2 && OP_LOW == 2'd1) ||
		  OP_CODE == 8'hA2)
	begin
		handle_immediate();
	end
	
	else
	
	// ZERO-PAGE & ZERO-PAGE INDEXED INSTRUCTIONS
	if ((OP_MID == 3'd1 && OP_LOW == 2'd1) || // NON-INDEXED
		 (OP_MID == 3'd1 && OP_LOW == 2'd2) ||
		 (OP_MID == 3'd1 && OP_LOW == 2'd0 && (OP_HIGH >= 3'd4 || OP_HIGH == 3'd1)) ||
		 (OP_MID == 3'd5 && OP_LOW == 2'd1) || // INDEXED
		 (OP_MID == 3'd5 && OP_LOW == 2'd2) ||
		 (OP_MID == 3'd5 && OP_LOW == 2'd0 && (OP_HIGH == 3'd4 || OP_HIGH == 3'd5)))
	begin
		handle_zeropage();
	end
	
	else
	
	// ABSOLUTE INSTRUCTIONS -- excluding JMP instructions
	if (OP_MID == 3'd3 && OP_CODE != 8'h0C && OP_CODE != 8'h4C && OP_CODE != 8'h6C)
	begin
		handle_absolute();
	end
	
	else
	
	// ABSOLUTE INDEXED INSTRUCTIONS
	if ((OP_MID == 3'd6 && OP_LOW == 2'd1) ||
		 (OP_MID == 3'd7 && OP_LOW == 2'd1) ||
		 (OP_MID == 3'd7 && OP_LOW == 2'd2 && OP_HIGH != 3'd4) ||
		 OP_CODE == 8'hBC)
	begin
		handle_absolute_indexed();
	end
	
	else
	
	// INDEXED INDIRECT (ind, X)
	if (OP_MID == 3'd0 && OP_LOW == 2'd1)
	begin
		handle_indexed_indirect();
	end
	
	else
	
	// INDIRECT INDEXED (ind), Y
	if (OP_MID == 3'd4 && OP_LOW == 2'd1)
	begin
		handle_indirect_indexed();
	end
	
	else
	
	// BRANCH
	if (OP_MID == 3'd4 && OP_LOW == 2'd0)
	begin
		handle_branch();
	end
	
	else begin
		// Any instruction executed that is not valid is
		// interpreted as a NOP instruction
		handle_immediate();
		
	end

endtask

task handle_implied;
	case(I_C)
		4'd1: begin

			// 2 cycle commands
			case(OP_CODE)

				8'hCA: DEX();			
				8'h88: DEY();
				
				8'hA8: TAY();
				8'hC8: INY();
				8'hE8: INX();
			
				8'h18: CLC(); 
				8'h38: SEC();
				8'h58: CLI();
				8'h78: SEI();
				8'h98: TYA();
				8'hB8: CLV();
				8'hD8: CLD();
				8'hF8: SED();
				
				// Result stored in ACC
				8'h0A: ASL_A();
				8'h2A: ROL_A();
				8'h4A: LSR_A();
				8'h6A: ROR_A();
				
				8'h8A: TXA(); 
				8'hAA: TAX();
				8'hEA: NOP();
				
				8'h9A: TXS();
				8'hBA: TSX();
				default: I_C <= I_C + 1'b1;
				
			endcase
			
			// 2+ cycle commands
			case(OP_CODE)
				8'h08: PHP();
				8'h28: PLP();
				8'h48: PHA();
				8'h68: PLA();
				default: next_instruction();
			endcase
			
		end
		4'd2: begin
			
			// 3 cycle commands
			case(OP_CODE)
				8'h08: PHP();
				8'h48: PHA();
				default: I_C <= I_C + 1'b1;
			endcase
			
			// 3+ cycle commands
			case(OP_CODE)
				8'h28: PLP();
				8'h68: PLA();
				default: next_instruction();
			endcase
			
		end
		4'd3: begin
			next_instruction();
			
			// 4 cycle commands
			case(OP_CODE)
				8'h28: PLP();
				8'h68: PLA();
			endcase
		end
	endcase
endtask

task handle_immediate;
	case(I_C)
		4'd1: begin
			
			case(OP_CODE)
				
				8'hC0: CPY();
				8'hE0: CPX();
				
				8'hA2: LDX();
				8'hA0: LDY();
				8'hA9: LDA();
				
				8'h09: ORA();
				8'h29: AND();
				8'h49: EOR();
				8'h69: ADC();
				
				8'hC9: CMP();
				8'hE9: SBC();
				default: NOP();
			endcase
			
			increment_pc();
			A_BUS <= PC + 1'd1;
			next_instruction();
		
		end
	endcase
endtask

task handle_zeropage;
	case(I_C)
		4'd1: begin
			// Set Address Bus to Operand location
			increment_pc();
			A_BUS <= {8'b0, DB_READ};
			
			if(OP_MID == 3'd1) begin
				// Non-indexed
				I_C <= I_C + 3'd2;
				
				// Write operations (Non-Indexed)
				if(OP_HIGH == 3'd4) 
				begin
					RW <= 1'b0;
					case(OP_CODE)
						8'h84: STY();
						8'h85: STA(); 
						8'h86: STX();
					endcase
				end
				
			end else begin
				// Indexed - Add either X or Y register to DB_READ via the ALU
				I_C <= I_C + 1'b1;
				ALU_A <= DB_READ;
				
				// STX, LDX opcodes indexed with Y
				if (OP_CODE == 8'h96 || OP_CODE == 8'hB6)
					ALU_B <= Y;
				else
					ALU_B <= X;
				
				SUM_en <= 1'b1;
				ALU_CIN <= 1'b0;
			end			
			
			
		end
		
		4'd2: begin
			SUM_en <= 1'b0;
			// Take the result of the ALU and set it to the DB_READ
			A_BUS <= {8'b0, ALU_OUT};
			I_C <= I_C + 1'b1;
			if(OP_HIGH == 3'd4)
			begin
				RW <= 1'b0;
				case(OP_CODE)
					// Write operations (Indexed)
					8'h94: STY();
					8'h95: STA();
					8'h96: STX();
				endcase
			end
		end
		
		4'd3: begin
			case(OP_CODE)
				// Read Operations
				8'h24: BIT();
				
				8'hA5: LDA();
				8'hB5: LDA();
				8'hA6: LDX();
				8'hB6: LDX();
				8'hA4: LDY();
				8'hB4: LDY();
				
				8'hC5: CMP();
				8'hD5: CMP();
				8'hC4: CPY();
				8'hE4: CPX();
				
				8'h05: ORA();
				8'h15: ORA();
				8'h25: AND();
				8'h35: AND();
				8'h45: EOR();
				8'h55: EOR();
				
				8'h65: ADC();
				8'h75: ADC();
				8'hE5: SBC();
				8'hF5: SBC();
			
				// RMW Operations
				8'h06: ASL();
				8'h16: ASL();
				8'h26: ROL();
				8'h36: ROL();
				8'h46: LSR();
				8'h56: LSR();
				8'h66: ROR();
				8'h76: ROR();
				
				8'hC6: DEC();
				8'hD6: DEC();
				8'hE6: INC();
				8'hF6: INC();
			endcase
			
			// RWM operations
			if(OP_LOW == 2'd2 && !(OP_HIGH == 3'd4 || OP_HIGH == 3'd5))
			begin
				I_C <= I_C + 1'd1;
				RW <= 0;
				DB_WRITE <= DB_READ;
			end
			else begin
			// Read / Write operations
				RW <= 1'b1;
				A_BUS <= PC;
				next_instruction();
			end
			
			
		end
		
		4'd4: begin
			DB_WRITE <= ALU_OUT;
			I_C <= I_C + 1'b1;
		
			if (UPDATE_NZ)
			begin
				UPDATE_NZ <= 1'b0;
				update_nz_flags(ALU_OUT);
			end
			
			if (UPDATE_CARRY)
			begin
				UPDATE_CARRY <= 1'b0;
				update_c_flag();
			end
		end
		
		4'd5: begin
			RW <= 1'b1;
			A_BUS <= PC;
			next_instruction();
		
		end
	endcase
endtask

task handle_absolute;
	case(I_C)
		4'd1: begin
			// fetch low byte
			increment_pc();
			A_BUS <= PC + 1'd1;
			ABL_HOLD <= DB_READ;
			I_C <= I_C + 1'd1;
		end
		
		4'd2: begin
			// fetch high byte
			increment_pc();
			A_BUS <= {DB_READ, ABL_HOLD};
			I_C <= I_C + 1'd1;
			
			// Perform write operations
			if(OP_HIGH == 3'd4)
			begin
				case(OP_CODE)
					8'h8C: STY();
					8'h8D: STA();
					8'h8E: STX();
				endcase
				RW <= 1'b0;
			end
				
			
		end
		
		4'd3: begin
			// Perform Read / RWM operations
			case(OP_CODE)
				8'h2C: BIT();
				
				8'hAD: LDA();
				8'hAE: LDX();
				8'hAC: LDY();
				
				8'hCD: CMP();
				8'hCC: CPY();
				8'hEC: CPX();
				
				8'h0D: ORA();
				8'h2D: AND();
				8'h4D: EOR();
				
				8'h6D: ADC();
				8'hED: SBC();
				
				8'h0E: ASL();
				8'h2E: ROL();
				8'h4E: LSR();
				8'h6E: ROR();
				
				8'hCE: DEC();
				8'hEE: INC();
			endcase
			
			// RWM operations
			if(OP_LOW == 2'd2 && !(OP_HIGH == 3'd4 || OP_HIGH == 3'd5))
			begin
				I_C <= I_C + 1'd1;
				RW <= 0;
			end
			else begin
			// Read / Write operations
				RW <= 1'b1;
				A_BUS <= PC;
				next_instruction();
			end
		end
		
		4'd4: begin
			DB_WRITE <= ALU_OUT;
			I_C <= I_C + 1'b1;
		
			update_flags();
		end
		
		4'd5: begin
			RW <= 1'b1;
			A_BUS <= PC;
			next_instruction();
		end
	endcase
endtask

task handle_absolute_indexed;
	case(I_C)
		4'd1: begin
			// fetch low byte
			increment_pc();
			A_BUS <= PC + 1'd1;
			I_C <= I_C + 1'd1;
			
			ALU_A <= DB_READ;
			if (OP_MID == 3'd6 && OP_LOW == 2'd1)
				// Y-indexed
				ALU_B <= Y;
			else
				// X-indexed
				ALU_B <= X;
			
			SUM_en <= 1'b1;
			ALU_CIN <= 1'b0;
			
		end
		4'd2: begin
			// fetch high byte
			increment_pc();
			A_BUS <= {DB_READ, ALU_OUT};
			
			ALU_A <= DB_READ;
			ALU_B <= ALU_COUT;
			
			// If read operation and carry out is true 
			if(!ALU_COUT && (OP_CODE == 8'hBC || OP_CODE == 8'hBE || (OP_MID == 3'd7 && OP_LOW == 2'd1 && OP_HIGH != 3'd4))) begin
				I_C <= I_C + 3'd2; // Skip next step if no ALU carry
				SUM_en <= 1'b0; // Reset ALU
			end else begin
				I_C <= I_C + 1'b1;
			end	
				
		end
		4'd3: begin
			A_BUS <= {ALU_OUT, A_BUS[7:0]};
			I_C <= I_C + 1'b1;
			SUM_en <= 1'b0; // Reset ALU
			
			// Execute write operations
			if(OP_CODE == 8'h99 || OP_CODE == 8'h9D)
			begin
				RW <= 0;
				STA();
			end
		
		end
		4'd4: begin
			// Execute read / RMW operations
			case(OP_CODE)
				
				// Y-indexed
				8'h19: ORA();
				8'h39: AND();
				8'h59: EOR();
				8'h79: ADC();
				//
				8'hB9: LDA();
				8'hD9: CMP();
				8'hF9: SBC();
				
				// X-indexed
				8'hBC: LDY();
				
				8'h1D: ORA();
				8'h3D: AND();
				8'h5D: EOR();
				8'h7D: ADC();
				//
				8'hBD: LDA();
				8'hDD: CMP();
				8'hFD: SBC();
				
				8'h1E: ASL();
				8'h3E: ROL();
				8'h5E: LSR();
				8'h7E: ROR();
				//
				8'hBE: LDX();
				8'hDE: DEC();
				8'hFE: INC();
			endcase
			
			if(OP_MID == 3'd7 && OP_LOW == 2'd2 && OP_HIGH != 3'd5) begin
				// RMW operations
				RW <= 1'b0;
				I_C <= I_C + 1'b1;
				
			end else begin
				// Read / Write operations
				RW <= 1'b1;
				next_instruction();
				A_BUS <= PC;
				
			end
		
		end
		4'd5: begin
			update_flags();
			DB_WRITE <= ALU_OUT;
			I_C <= I_C + 1'b1;
		end
		4'd6: begin
			RW <= 1'b1;
			next_instruction();
			A_BUS <= PC;
		end
	endcase
endtask

task handle_indexed_indirect;
	case(I_C)
		4'd1: begin
			increment_pc();
			A_BUS <= {8'b0, DB_READ};
			I_C <= I_C + 1'b1;
			
			ALU_A <= DB_READ;
			ALU_B <= X;
			
			SUM_en <= 1'b1;
			ALU_CIN <= 1'b0;
			
			I_C <= I_C + 1'b1;
		end
		4'd2: begin
			A_BUS <= {8'b0, ALU_OUT};
			ALU_A <= ALU_OUT;
			ALU_B <= 8'b1;
			I_C <= I_C + 1'b1;
		end
		4'd3: begin
			A_BUS <= {8'b0, ALU_OUT};
			ABL_HOLD <= DB_READ;
			SUM_en <= 1'b0;
			I_C <= I_C + 1'b1;
		end
		4'd4: begin
			A_BUS <= {DB_READ, ABL_HOLD};
			
			if(OP_CODE == 8'h81) begin
				RW <= 1'b0;
				STA();
			end
			I_C <= I_C + 1'b1;
		end
		4'd5: begin
			case(OP_CODE)
				8'h01: ORA();
				8'h21: AND();
				8'h41: EOR();
				8'h61: ADC();
				//
				8'hA1: LDA();
				8'hC1: CMP();
				8'hE1: SBC();
			endcase
			RW <= 1'b1;
			A_BUS <= PC;
			next_instruction();
		end
	endcase
endtask

task handle_indirect_indexed;
	case(I_C)
		4'd1: begin
			// Fetch zeropage index
			increment_pc();
			A_BUS <= {8'b0, DB_READ};
			
			ALU_A <= DB_READ;
			ALU_B <= 1'b1;
			
			SUM_en <= 1'b1;
			ALU_CIN <= 1'b0;
			I_C <= I_C + 1'b1;
		end
		4'd2: begin
			// Fetch low byte, add Y index to it
			A_BUS <= {8'b0, ALU_OUT};
			ALU_A <= DB_READ;
			ALU_B <= Y;
			I_C <= I_C + 1'b1;
		end
		4'd3: begin
			// Fetch high byte, check for carry from low byte, add to high byte
			A_BUS <= {DB_READ, ALU_OUT};
			
			// If is read operation and cout is 0
			if (OP_CODE != 8'h91 && ALU_COUT == 1'b0) begin
				I_C <= I_C + 3'd2;
				SUM_en <= 1'b0;
			end else begin
				I_C <= I_C + 1'b1;
				ALU_A <= DB_READ;
				ALU_B <= ALU_COUT;
			end
		end
		4'd4: begin
			// Correct high byte, execute write operations
			A_BUS <= {ALU_OUT, A_BUS[7:0]};
			if (OP_CODE == 8'h91) begin
				STA();
				RW <= 0;
			end
			
			SUM_en <= 1'b0;
			I_C <= I_C + 1'b1;
		end
		4'd5: begin
			// Execute read operations
			case(OP_CODE)
			
				8'h11: ORA();
				8'h31: AND();
				8'h51: EOR();
				8'h71: ADC();
				//
				8'hB1: LDA();
				8'hD1: CMP();
				8'hF1: SBC();
			endcase
			RW <= 1;
			next_instruction();
			A_BUS <= PC;
		
		end
	endcase
endtask

task handle_branch;
	case(I_C)
		4'd1: begin
			case(OP_CODE)
				8'h10: BPL();
				8'h30: BMI();
				8'h50: BVC();
				8'h70: BVS();
				8'h90: BCC();
				8'hB0: BCS();
				8'hD0: BNE();
				8'hF0: BEQ();
			endcase
			
			increment_pc();
			A_BUS <= PC + 1'b1;
			
		end
		4'd2: begin
			// Branch was taken			
			PCL <= ALU_OUT;
			A_BUS <= {PCH, ALU_OUT};
			
			
			if (ALU_COUT && ALU_B[7] == 0) begin
				// PCH needs to be fixed
				ALU_A <= PCH;
				ALU_B <= 1'b1;
				ALU_CIN <= 1'b0;
			
				I_C <= I_C + 1'd1;
			end else if (!ALU_COUT && ALU_B[7] == 1) begin
				ALU_A <= PCH;
				ALU_B <= 1'b1;
				ALU_CIN <= 1'b1;
				INV_en <= 1'b1;
				
				I_C <= I_C + 1'd1;
			end else begin
				// PCH is correct, fetch next instruction
				next_instruction();
			end
				
		end
		4'd3: begin
			PCH <= ALU_OUT;
			A_BUS <= {ALU_OUT, PCL};
			next_instruction();
		end
	endcase
endtask

task decide_branch(input take_branch);
	if (take_branch) begin
		
		// Add operand to PCL
		// Acts as PC increment
		ALU_A <= PCL;
		ALU_B <= DB_READ;

		SUM_en <= 1'b1; 
		ALU_CIN <= 1'b1; 
		
		I_C <= I_C + 1'b1;
		
	end else begin
		// Branch was not taken, go to the next instruction
		next_instruction();
		
	end
endtask

task increment_pc;
	PCL <= PCL + 1'b1;
	if (PCL == 8'hFF)
		PCH <= PCH + 1'b1;
endtask

task update_flags;
	// Normally, the instruction sets which flags need to be updated.
	// To emulate the 6502, the relevant flags are updated the next 
	// clock cycle.
	if (UPDATE_NZ)
	begin
		UPDATE_NZ <= 1'b0;
		update_nz_flags(ALU_OUT);
	end
	
	if(UPDATE_Z)
	begin
		UPDATE_Z <= 1'b0;
		update_z_flag();
	end

	if (UPDATE_CARRY)
	begin
		UPDATE_CARRY <= 1'b0;
		update_c_flag();
	end
	
	if (UPDATE_OVF)
	begin
		UPDATE_OVF <= 1'b0;
		update_ovf_flag();
	end
endtask

task update_nz_flags(input [7:0] i);
	// Update the Negative & Zero flags
	STAT[1] <= i == 0 ? 1'd1 : 1'd0; // Zero Flag
	STAT[7] <= i[7] == 1'b1; // Negative Flag
endtask

task update_z_flag();
	// Update Zero flag
	STAT[1] <= ALU_OUT == 0 ? 1'd1: 1'd0;

endtask

task update_c_flag();
	// Update Carry flag
	STAT[0] <= ALU_COUT;
endtask

task update_ovf_flag();
	// Update Overflow flag
	STAT[6] <= ALU_OVERFLOW;
endtask

task save_alu_result;
	if(X_SAVE)
	begin
		X <= ALU_OUT;
		X_SAVE <= 0;
	end else if(Y_SAVE)
	begin
		Y <= ALU_OUT;
		Y_SAVE <= 0;
	end else if(ACC_SAVE)
	begin
		// Is a result of a ALU operation
		ACC <= ALU_OUT;
		ACC_SAVE <= 0;					
	end
endtask

task next_instruction();
	I_C <= 0;
	SYNC <= 1'b1;
endtask

task alu_reset;
	SUM_en <= 1'b0;
	AND_en <= 1'b0;
	EOR_en <= 1'b0;
	OR_en  <= 1'b0;
	ASL_en <= 1'b0;
	LSR_en <= 1'b0;
	INV_en <= 1'b0;
	ROL_en <= 1'b0;
	ROR_en <= 1'b0;
	ALU_CIN <= 1'b0;
endtask

task cpu_reset;
	CPU_STATE <= S_STARTUP;
	I_C <= 3'b0;
	
	// Reset kinda dangerous since CPU
	// could be performing a write at the same time
	RW <= 1'b1;
	
	// Reset index registers
	X <= 8'b0;
	Y <= 8'b0;
	ACC <= 8'b0;
	STAT <= 8'h16;
	SP <= 8'hFD;
	
	// Reset ALU
	alu_reset();
	ALU_A <= 8'b0;
	ALU_B <= 8'b0;
	ALU_CIN <= 1'b0;
	UPDATE_NZ = 1'b0;
	UPDATE_Z = 1'b0;
	UPDATE_CARRY = 1'b0;
	UPDATE_OVF = 1'b0;

endtask

ALU ALU
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
   .Ain(ALU_A),
	.Bin(ALU_B), 
   .Cin(ALU_CIN), 	
   .RES(ALU_OUT),		
   .Cout(ALU_COUT), 
   .OVFout(ALU_OVERFLOW)
);

falling_edge_detector NMI_INTERRUPT (
	.clk(clk),
	.trigger(NMI),
	.clear(NMI_RESET),
	
	.out(NMI_TRIGGERED)
);


endmodule
