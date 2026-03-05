module register_dut(
 
		input  logic clk,rst,addr,wr_enb,

		input  logic [7:0] din,
 
		output logic [7:0] dout
 
		);
 
 
		logic [7:0] tempreg0 ;				// dut internal register

											// offset addr 'h0

		always_ff @(posedge clk) begin: B1
 
			if(rst) begin: B1
 
				tempreg0 <= '0;

			end: B1

			else if(wr_enb) begin: B2		// if wr_enb == '1
 
				if(!addr) tempreg0 <= din;
 
			end: B2
 
			else if(!wr_enb) begin: B3		// if wr_enb == '0
 
				if(!addr) dout <= tempreg0;
 
			end: B3
 
		end: B1
 
 
endmodule: register_dut
 
