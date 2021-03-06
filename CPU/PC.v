`include "defines.v"

module PC
(
	input  wire            clk, rst, stall,
	
	input  wire            flush,
	input  wire [`AddrBus] new_pc,
	input  wire            bflag,
	input  wire [`AddrBus] baddr,
	
	output reg  [`AddrBus] pc,
	output reg  [`DataBus] excp
);
	
	always @(posedge clk, posedge rst) begin
		if (rst) begin
			pc      <= `ENT_START;
		end
		else begin
			casez ({stall, bflag, flush})
				3'b000: pc <= pc + 32'h4;
				3'b010: pc <= baddr;
				3'b??1: pc <= new_pc;
			endcase
		end
	end
	
	always @(*) begin
		excp             <= `ZeroWord;
		excp[`EXC_IADEL] <= pc[1:0] != 2'b00;
	end
	
endmodule


