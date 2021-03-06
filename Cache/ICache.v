`define State_Idle 0
`define State_Addr 1
`define State_Data 2
`define State_Wait 3

module ICache (
	input  wire        clk,
	input  wire        rst,
	input  wire        flush,
	//AXI signals
	output reg  [ 3:0] axim_arid,
	output reg  [31:0] axim_araddr,
	output reg  [ 3:0] axim_arlen,
	output wire [ 2:0] axim_arsize,
	output wire [ 1:0] axim_arburst,
	output wire [ 1:0] axim_arlock,
	output wire [ 3:0] axim_arcache,
	output wire [ 2:0] axim_arprot,
	output reg         axim_arvalid,
	input  wire        axim_arready,
	input  wire [ 3:0] axim_rid,
	input  wire [31:0] axim_rdata,
	input  wire [ 1:0] axim_rresp,
	input  wire        axim_rlast,
	input  wire        axim_rvalid,
	output wire        axim_rready,
	output wire [ 3:0] axim_awid,
	output wire [31:0] axim_awaddr,
	output wire [ 3:0] axim_awlen,
	output wire [ 2:0] axim_awsize,
	output wire [ 1:0] axim_awburst,
	output wire [ 1:0] axim_awlock,
	output wire [ 3:0] axim_awcache,
	output wire [ 2:0] axim_awprot,
	output wire        axim_awvalid,
	input  wire        axim_awready,
	output wire [ 3:0] axim_wid,
	output wire [31:0] axim_wdata,
	output wire [ 3:0] axim_wstrb,
	output wire        axim_wlast,
	output wire        axim_wvalid,
	input  wire        axim_wready,
	input  wire [ 3:0] axim_bid,
	input  wire [ 1:0] axim_bresp,
	input  wire        axim_bvalid,
	output wire        axim_bready,
	//SRAM signals
	input  wire        iram_en,
	input  wire [31:0] iram_addr,
	output wire [31:0] iram_rdata,
	output wire        iram_sreq,
	input  wire        iram_stall,
//	input  wire        iram_cached,
	input  wire        iram_hitiv,
	input  wire [31:0] iram_ivaddr
);
	
	//Fixed AXI signals
	assign axim_arsize   =  3'b010;
	assign axim_arburst  =  2'b01;
	assign axim_arlock   =  2'b0;
	assign axim_arcache  =  4'b0;
	assign axim_arprot   =  3'b0;
	assign axim_rready   =  1'b1;
	assign axim_awid     =  4'b0;
	assign axim_awaddr   = 32'b0;
	assign axim_awlen    =  4'b0;
	assign axim_awsize   =  3'b010;
	assign axim_awburst  =  2'b01;
	assign axim_awlock   =  2'b0;
	assign axim_awcache  =  4'b0;
	assign axim_awprot   =  3'b0;
	assign axim_awvalid  =  1'b0;
	assign axim_wid      =  4'b0;
	assign axim_wdata    = 32'b0;
	assign axim_wstrb    =  4'b0;
	assign axim_wlast    =  1'b0;
	assign axim_wvalid   =  1'b0;
	assign axim_bready   =  1'b1;
	
	reg         ena  , enb;
	reg  [ 3:0] wea  , web;
	reg  [11:0] addra, addrb;
	reg  [31:0] dina , dinb;
	wire [31:0] douta, doutb;
	
	//Port A: CPU read & write
	//Port B: AXI read & write
	Inst_Cache icache (
	  .clka  (clk),		// input wire clka
	  .ena   (ena),		// input wire ena
	  .wea   (wea),		// input wire [3 : 0] wea
	  .addra (addra),	// input wire [11 : 0] addra
	  .dina  (dina),	// input wire [31 : 0] dina
	  .douta (douta),	// output wire [31 : 0] douta
	  
	  .clkb  (clk),		// input wire clkb
	  .enb   (enb),		// input wire enb
	  .web   (web),		// input wire [3 : 0] web
	  .addrb (addrb),	// input wire [11 : 0] addrb
	  .dinb  (dinb),	// input wire [31 : 0] dinb
	  .doutb (doutb)	// output wire [31 : 0] doutb
	);
	
	//Cached
	reg  [17:0] cache_haddr [255:0];
	reg         cache_valid [255:0];

	wire [ 3:0] addr_wdsel = iram_addr[ 5: 2];
	wire [ 7:0] addr_lnsel = iram_addr[13: 6];
	wire [17:0] addr_haddr = iram_addr[31:14];
	wire [17:0] line_haddr = cache_haddr[addr_lnsel];
	wire        line_valid = cache_valid[addr_lnsel];
	wire        cache_hit  = (line_haddr == addr_haddr) && line_valid;
	
	wire [ 7:0] ivad_lnsel = iram_ivaddr[13: 6];
	wire [17:0] ivad_haddr = iram_ivaddr[31:14];
	wire [17:0] ivln_haddr = cache_haddr[ivad_lnsel];
	wire        ivln_valid = cache_valid[ivad_lnsel];
	wire        iv_hit     = (ivln_haddr == ivad_haddr) && ivln_valid;
	
	
	//Hit Invalidate
	reg    rd_sreq;
	assign iram_sreq = iram_hitiv || rd_sreq;
	
	//Stall Request
	always @(*) begin
		if(rst) begin
			rd_sreq <=  1'b0;
			ena     <=  1'b0;
			wea     <=  4'b0;
			addra   <= 32'b0;
		end
		else begin
			rd_sreq <=  1'b0;
			ena     <=  1'b0;
			wea     <=  4'b0;
			addra   <= 32'b0;
			
			if(iram_en) begin
				if(cache_hit) begin
					rd_sreq <= 1'b0;
					ena     <= !iram_stall;
					wea     <= 4'b0;
					addra   <= iram_addr[13:2];
				end
				else begin
					rd_sreq <= !flush;
				end
			end
		end
	end
	
	//DFA
	reg [ 1:0] state;
	reg [31:0] lk_addr;
	reg [ 3:0] cnt;
	
	wire [7:0] lk_lnsel = lk_addr[13:6];
	integer i;
	
	always @(posedge clk, posedge rst) begin
		if(rst) begin
			for(i = 0; i < 256; i = i + 1) begin
				cache_haddr[i] <= 18'b0;
				cache_valid[i] <=  1'b0;
			end
			state        <= `State_Idle;
			axim_arid    <=  4'b0;
			axim_araddr  <= 32'b0;
			axim_arlen   <=  4'b0;
			axim_arvalid <=  1'b0;
			
			enb   <=  1'b0;
			web   <=  4'h0;
			addrb <= 12'b0;
			dinb  <= 32'b0;
			
			cnt     <=  4'b0;
			lk_addr <= 32'b0;     
		end
		else begin
			axim_arid    <=  4'b0;
			axim_araddr  <= 32'b0;
			axim_arlen   <=  4'b0;
			axim_arvalid <=  1'b0;
			
			enb   <=  1'b0;
			web   <=  4'h0;
			addrb <= 12'b0;
			dinb  <= 32'b0;
			
			case(state)
				`State_Idle: begin
					if(!cache_hit && !iram_hitiv) begin
						lk_addr <= {iram_addr[31:6], 6'b0};
						cnt     <= 4'b0;
						state   <= `State_Addr;
						cache_haddr[addr_lnsel] <= addr_haddr;
						cache_valid[addr_lnsel] <= 1'b0;
					end
					else if(iram_hitiv && iv_hit) begin
						cache_valid[ivad_lnsel] <= 1'b0;
					end
				end
				
				`State_Addr: begin
					if(axim_arvalid && axim_arready) begin
						state <= `State_Data;
					end
					else begin
						axim_arid    <= 4'b0001;
						axim_araddr  <= lk_addr;
						axim_arlen   <= 4'hF;
						axim_arvalid <= 1'b1;
					end
				end
				
				`State_Data: begin
					if(axim_rvalid) begin
						enb   <= 1'b1;
						web   <= 4'hF;
						addrb <= {lk_lnsel, cnt};
						dinb  <= axim_rdata;
						cnt   <= cnt + 4'h1;
						if(axim_rlast) begin
							state <= `State_Wait;
						end
					end
				end
				
				`State_Wait: begin
					cache_haddr[lk_lnsel] <= lk_addr[31:14];
					cache_valid[lk_lnsel] <= 1'b1;
					if(iram_stall == rd_sreq) state <= `State_Idle;
				end
				
			endcase
		end
	end
	
	reg lk_flush;
	always @(posedge clk, posedge rst) begin
		if(rst) lk_flush <= 1'b0;
		else
			if(!iram_stall) lk_flush <= flush;
	end
	
	assign iram_rdata = lk_flush ? 1'b0 : douta;//iram_stall ? 32'b0 : douta;
	
endmodule
	