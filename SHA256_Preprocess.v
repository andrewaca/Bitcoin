module Preprocess(CLK, nreset, msg, length, new_msg, done);
	input CLK, nreset;
	input [63:0] length;
	input [2047:0] msg;
	output reg [2047:0] new_msg;
	output done;

	reg [1:0] state;
	reg [8:0] k,n;

	localparam
	SOLVE_K = 2'd0,
	CONCATENATE = 2'd1,
	DONE 	= 2'd2;
	
	assign done = state == DONE;
	
	/*
	length of message = l
	append bit '1' to message

	solve equation l + k + 1 = 448 mod 512
	-> l + k + 1 + 512*n = 448
	-> k = 512*n+447-l, (n=0,1,2... integer, 512*n+447 > l)
	new_msg = msg.1.k_zeros.length, where '.' is concatenation
	*/
	
	always @(posedge CLK, negedge nreset)
	begin: CU
		if (~nreset)
		begin
			n <= 0;
			k <= 0;
			state <= SOLVE_K;			
			end
		else
		begin
			case (state)
				SOLVE_K:
				begin
					if(512*n+447 >= length) begin
						state <= DONE;
						k <= 512*n+447-l;
					end else begin
						n <= n+1;
						state <= SOLVE_K;
					end
				end
				CONCATENATE:
				begin
					new_msg <= {msg,1'b1,{k{1'b0}},length};
				end
				DONE:
				begin
					k <= k;
				end
		endcase
		end
	end
endmodule