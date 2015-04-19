/*
 * These source files contain a hardware description of a network
 * automatically generated by CONNECT (CONfigurable NEtwork Creation Tool).
 *
 * This product includes a hardware design developed by Carnegie Mellon
 * University.
 *
 * Copyright (c) 2012 by Michael K. Papamichael, Carnegie Mellon University
 *
 * For more information, see the CONNECT project website at:
 *   http://www.ece.cmu.edu/~mpapamic/connect
 *
 * This design is provided for internal, non-commercial research use only,
 * cannot be used for, or in support of, goods or services, and is not for
 * redistribution, with or without modifications.
 *
 * You may not use the name "Carnegie Mellon University" or derivations
 * thereof to endorse or promote products derived from this software.
 *
 * THE SOFTWARE IS PROVIDED "AS-IS" WITHOUT ANY WARRANTY OF ANY KIND, EITHER
 * EXPRESS, IMPLIED OR STATUTORY, INCLUDING BUT NOT LIMITED TO ANY WARRANTY
 * THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS OR BE ERROR-FREE AND ANY
 * IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 * TITLE, OR NON-INFRINGEMENT.  IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY
 * BE LIABLE FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO DIRECT, INDIRECT,
 * SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING OUT OF, RESULTING FROM, OR IN
 * ANY WAY CONNECTED WITH THIS SOFTWARE (WHETHER OR NOT BASED UPON WARRANTY,
 * CONTRACT, TORT OR OTHERWISE).
 *
 */


/* =========================================================================
 *
 * Filename:            testbench_sample.v
 * Date created:        05-28-2012
 * Last modified:       06-09-2012
 * Authors:		Michael Papamichael <papamixATcs.cmu.edu>
 *
 * Description:
 * Minimal testbench sample for CONNECT networks
 *
 * =========================================================================
 */

`timescale 1ns / 1ps

`include "connect_parameters.v"


module CONNECT_testbench_sample();
  parameter HalfClkPeriod = 5;
  localparam ClkPeriod = 2*HalfClkPeriod;

  // non-VC routers still reeserve 1 dummy bit for VC.
  localparam vc_bits = (`NUM_VCS > 1) ? $clog2(`NUM_VCS) : 1;
  localparam dest_bits = $clog2(`NUM_USER_RECV_PORTS);
  localparam flit_port_width = 2 /*valid and tail bits*/+ `FLIT_DATA_WIDTH + dest_bits + vc_bits;
  localparam credit_port_width = 1 + vc_bits; // 1 valid bit
  localparam test_cycles = 20;

  reg Clk;
  reg Rst_n;

  // input regs
  reg send_flit [0:`NUM_USER_SEND_PORTS-1]; // enable sending flits
  reg [flit_port_width-1:0] flit_in [0:`NUM_USER_SEND_PORTS-1]; // send port inputs

  reg send_credit [0:`NUM_USER_RECV_PORTS-1]; // enable sending credits
  reg [credit_port_width-1:0] credit_in [0:`NUM_USER_RECV_PORTS-1]; //recv port credits

  // output wires
  wire [credit_port_width-1:0] credit_out [0:`NUM_USER_SEND_PORTS-1];
  wire [flit_port_width-1:0] flit_out [0:`NUM_USER_RECV_PORTS-1];

  reg [31:0] cycle;
  integer i;

  // packet fields
  reg is_valid;
  reg is_tail;
  reg [dest_bits-1:0] dest;
  reg [vc_bits-1:0]   vc;
  reg [`FLIT_DATA_WIDTH-1:0] data;

  // Counter
  localparam counter_bits = $clog2(`FLIT_BUFFER_DEPTH) + 1;
  // 0 <= counter[vc] <= 16 
  reg [counter_bits - 1 : 0] credit_counter [0:`NUM_USER_RECV_PORTS-1];
  
  // Generate Clock
  initial Clk = 0;
  always #(HalfClkPeriod) Clk = ~Clk;

  // Run simulation
  initial begin
    cycle = 0;
    for(i = 0; i < `NUM_USER_SEND_PORTS; i = i + 1) begin flit_in[i] = 0; send_flit[i] = 0; end
    for(i = 0; i < `NUM_USER_RECV_PORTS; i = i + 1) begin credit_in[i] = 0; send_credit[i] = 0; end
	
	for(i = 0; i < `NUM_USER_RECV_PORTS; i = i + 1) begin credit_counter[i] = `FLIT_BUFFER_DEPTH; end

    $display("---- Performing Reset ----");
    Rst_n = 0; // perform reset (active low)
    #(5*ClkPeriod+HalfClkPeriod);
    Rst_n = 1;
    #(HalfClkPeriod);

    // send a 2-flit packet from send port 0 to receive port 1
	if(credit_counter[0] > 1) begin
		send_flit[0] = 1'b1;
		dest = 1;
		vc = 0;
		data = 'ha;
		flit_in[0] = {1'b1 /*valid*/, 1'b0 /*tail*/, dest, vc, data};
		$display("@%3d: Injecting flit %x into send port %0d", cycle, flit_in[0], 0);
	end

    #(ClkPeriod);
    // send 2nd flit of packet
	if(credit_counter[0] > 1) begin
		send_flit[0] = 1'b1;
		data = 'hb;
		flit_in[0] = {1'b1 /*valid*/, 1'b1 /*tail*/, dest, vc, data};
		$display("@%3d: Injecting flit %x into send port %0d", cycle, flit_in[0], 0);
	end

    #(ClkPeriod);
    // stop sending flits
    send_flit[0] = 1'b0;
    flit_in[0] = 'b0; // valid bit
  end


  // Monitor arriving flits
  always @ (posedge Clk) begin
    cycle <= cycle + 1;
    for(i = 0; i < `NUM_USER_RECV_PORTS; i = i + 1) begin
      if(flit_out[i][flit_port_width-1]) begin // valid flit
        $display("@%3d: Ejecting flit %x at receive port %0d", cycle, flit_out[i], i);
      end
    end

    // terminate simulation
    if (cycle > test_cycles) begin
      $finish();
    end
  end

	// Add your code to handle flow control here (sending receiving credits)
  always @ (posedge Clk) begin
	// Increment counter after flit leaves router
    for(i = 0; i < `NUM_USER_RECV_PORTS; i = i + 1) begin
      if(credit_out[i][credit_port_width-1]) begin // Valid credit
		send_credit[i] <= 1'b1;
		credit_in[i] <= 3'b100;
		if(credit_counter[i] < 16)
			credit_counter[i] <= credit_counter[i] + 1; // Only using vc 0
      end else begin
		  send_credit[i] <= 0;
		  credit_in[i] <= 0;
	  end
    end
  
	// Decrement counter after send
    for(i = 0; i < `NUM_USER_SEND_PORTS; i = i + 1) begin
      if(send_flit[i] == 1'b1) begin // valid flit
		if(credit_counter[i] > 0)
			credit_counter[i] <= credit_counter[i] - 1;
      end
    end
  end 
  
  
  // Instantiate CONNECT network
  mkNetwork dut
  (.CLK(Clk)
   ,.RST_N(Rst_n)

   // send ports 0-4
   ,.send_ports_0_putFlit_flit_in(flit_in[0])
   ,.EN_send_ports_0_putFlit(send_flit[0])
   ,.EN_send_ports_0_getCredits(1'b1) // drain credits
   ,.send_ports_0_getCredits(credit_out[0])

   ,.send_ports_1_putFlit_flit_in(flit_in[1])
   ,.EN_send_ports_1_putFlit(send_flit[1])
   ,.EN_send_ports_1_getCredits(1'b1)
   ,.send_ports_1_getCredits(credit_out[1])

   ,.send_ports_2_putFlit_flit_in(flit_in[2])
   ,.EN_send_ports_2_putFlit(send_flit[2])
   ,.EN_send_ports_2_getCredits(1'b1)
   ,.send_ports_2_getCredits(credit_out[2])

   ,.send_ports_3_putFlit_flit_in(flit_in[3])
   ,.EN_send_ports_3_putFlit(send_flit[3])
   ,.EN_send_ports_3_getCredits(1'b1)
   ,.send_ports_3_getCredits(credit_out[3])

   ,.send_ports_4_putFlit_flit_in(flit_in[4])
   ,.EN_send_ports_4_putFlit(send_flit[4])
   ,.EN_send_ports_4_getCredits(1'b1)
   ,.send_ports_4_getCredits(credit_out[4])

   // send ports 5-9
   ,.send_ports_5_putFlit_flit_in(flit_in[5])
   ,.EN_send_ports_5_putFlit(send_flit[5])
   ,.EN_send_ports_5_getCredits(1'b1)
   ,.send_ports_5_getCredits(credit_out[5])

   ,.send_ports_6_putFlit_flit_in(flit_in[6])
   ,.EN_send_ports_6_putFlit(send_flit[6])
   ,.EN_send_ports_6_getCredits(1'b1)
   ,.send_ports_6_getCredits(credit_out[6])

   ,.send_ports_7_putFlit_flit_in(flit_in[7])
   ,.EN_send_ports_7_putFlit(send_flit[7])
   ,.EN_send_ports_7_getCredits(1'b1)
   ,.send_ports_7_getCredits(credit_out[7])

   ,.send_ports_8_putFlit_flit_in(flit_in[8])
   ,.EN_send_ports_8_putFlit(send_flit[8])
   ,.EN_send_ports_8_getCredits(1'b1)
   ,.send_ports_8_getCredits(credit_out[8])

   ,.send_ports_9_putFlit_flit_in(flit_in[9])
   ,.EN_send_ports_9_putFlit(send_flit[9])
   ,.EN_send_ports_9_getCredits(1'b1)
   ,.send_ports_9_getCredits(credit_out[9])

   // send ports 10-14
   ,.send_ports_10_putFlit_flit_in(flit_in[10])
   ,.EN_send_ports_10_putFlit(send_flit[10])
   ,.EN_send_ports_10_getCredits(1'b1)
   ,.send_ports_10_getCredits(credit_out[10])

   ,.send_ports_11_putFlit_flit_in(flit_in[11])
   ,.EN_send_ports_11_putFlit(send_flit[11])
   ,.EN_send_ports_11_getCredits(1'b1)
   ,.send_ports_11_getCredits(credit_out[11])
 
   ,.send_ports_12_putFlit_flit_in(flit_in[12])
   ,.EN_send_ports_12_putFlit(send_flit[12])
   ,.EN_send_ports_12_getCredits(1'b1)
   ,.send_ports_12_getCredits(credit_out[12])

   ,.send_ports_13_putFlit_flit_in(flit_in[13])
   ,.EN_send_ports_13_putFlit(send_flit[13])
   ,.EN_send_ports_13_getCredits(1'b1)
   ,.send_ports_13_getCredits(credit_out[13])
   
   ,.send_ports_14_putFlit_flit_in(flit_in[14])
   ,.EN_send_ports_14_putFlit(send_flit[14])
   ,.EN_send_ports_14_getCredits(1'b1)
   ,.send_ports_14_getCredits(credit_out[14])

   // send ports 15-19
   ,.send_ports_15_putFlit_flit_in(flit_in[15])
   ,.EN_send_ports_15_putFlit(send_flit[15])
   ,.EN_send_ports_15_getCredits(1'b1)
   ,.send_ports_15_getCredits(credit_out[15])

   ,.send_ports_16_putFlit_flit_in(flit_in[16])
   ,.EN_send_ports_16_putFlit(send_flit[16])
   ,.EN_send_ports_16_getCredits(1'b1)
   ,.send_ports_16_getCredits(credit_out[16])
   
   ,.send_ports_17_putFlit_flit_in(flit_in[17])
   ,.EN_send_ports_17_putFlit(send_flit[17])
   ,.EN_send_ports_17_getCredits(1'b1)
   ,.send_ports_17_getCredits(credit_out[17])

   ,.send_ports_18_putFlit_flit_in(flit_in[18])
   ,.EN_send_ports_18_putFlit(send_flit[18])
   ,.EN_send_ports_18_getCredits(1'b1)
   ,.send_ports_18_getCredits(credit_out[18])
   
   ,.send_ports_19_putFlit_flit_in(flit_in[19])
   ,.EN_send_ports_19_putFlit(send_flit[19])
   ,.EN_send_ports_19_getCredits(1'b1)
   ,.send_ports_19_getCredits(credit_out[19])

	// send ports 20-24
   ,.send_ports_20_putFlit_flit_in(flit_in[20])
   ,.EN_send_ports_20_putFlit(send_flit[20])
   ,.EN_send_ports_20_getCredits(1'b1)
   ,.send_ports_20_getCredits(credit_out[20])
   
   ,.send_ports_21_putFlit_flit_in(flit_in[21])
   ,.EN_send_ports_21_putFlit(send_flit[21])
   ,.EN_send_ports_21_getCredits(1'b1)
   ,.send_ports_21_getCredits(credit_out[21])
   
   ,.send_ports_22_putFlit_flit_in(flit_in[22])
   ,.EN_send_ports_22_putFlit(send_flit[22])
   ,.EN_send_ports_22_getCredits(1'b1)
   ,.send_ports_22_getCredits(credit_out[22])
   
   ,.send_ports_23_putFlit_flit_in(flit_in[23])
   ,.EN_send_ports_23_putFlit(send_flit[23])
   ,.EN_send_ports_23_getCredits(1'b1)
   ,.send_ports_23_getCredits(credit_out[23])

   ,.send_ports_24_putFlit_flit_in(flit_in[24])
   ,.EN_send_ports_24_putFlit(send_flit[24])
   ,.EN_send_ports_24_getCredits(1'b1)
   ,.send_ports_24_getCredits(credit_out[24])
	  
	  
	//
	//receive ports 0-4
   ,.EN_recv_ports_0_getFlit(1'b1) // drain flits
   ,.recv_ports_0_getFlit(flit_out[0])
   ,.recv_ports_0_putCredits_cr_in(credit_in[0])
   ,.EN_recv_ports_0_putCredits(send_credit[0])

   ,.EN_recv_ports_1_getFlit(1'b1)
   ,.recv_ports_1_getFlit(flit_out[1])
   ,.recv_ports_1_putCredits_cr_in(credit_in[1])
   ,.EN_recv_ports_1_putCredits(send_credit[1])
   
   ,.EN_recv_ports_2_getFlit(1'b1)
   ,.recv_ports_2_getFlit(flit_out[2])
   ,.recv_ports_2_putCredits_cr_in(credit_in[2])
   ,.EN_recv_ports_2_putCredits(send_credit[2])
   
   ,.EN_recv_ports_3_getFlit(1'b1)
   ,.recv_ports_3_getFlit(flit_out[3])
   ,.recv_ports_3_putCredits_cr_in(credit_in[3])
   ,.EN_recv_ports_3_putCredits(send_credit[3])
   
   ,.EN_recv_ports_4_getFlit(1'b1)
   ,.recv_ports_4_getFlit(flit_out[4])
   ,.recv_ports_4_putCredits_cr_in(credit_in[4])
   ,.EN_recv_ports_4_putCredits(send_credit[4])
   
 	//receive ports 5-9
   ,.EN_recv_ports_5_getFlit(1'b1)
   ,.recv_ports_5_getFlit(flit_out[5])
   ,.recv_ports_5_putCredits_cr_in(credit_in[5])
   ,.EN_recv_ports_5_putCredits(send_credit[5])

   ,.EN_recv_ports_6_getFlit(1'b1)
   ,.recv_ports_6_getFlit(flit_out[6])
   ,.recv_ports_6_putCredits_cr_in(credit_in[6])
   ,.EN_recv_ports_6_putCredits(send_credit[6])
   
   ,.EN_recv_ports_7_getFlit(1'b1)
   ,.recv_ports_7_getFlit(flit_out[7])
   ,.recv_ports_7_putCredits_cr_in(credit_in[7])
   ,.EN_recv_ports_7_putCredits(send_credit[7])
   
   ,.EN_recv_ports_8_getFlit(1'b1)
   ,.recv_ports_8_getFlit(flit_out[8])
   ,.recv_ports_8_putCredits_cr_in(credit_in[8])
   ,.EN_recv_ports_8_putCredits(send_credit[8])
   
   ,.EN_recv_ports_9_getFlit(1'b1)
   ,.recv_ports_9_getFlit(flit_out[9])
   ,.recv_ports_9_putCredits_cr_in(credit_in[9])
   ,.EN_recv_ports_9_putCredits(send_credit[9]) 

 	//receive ports 10-14
   ,.EN_recv_ports_10_getFlit(1'b1)
   ,.recv_ports_10_getFlit(flit_out[10])
   ,.recv_ports_10_putCredits_cr_in(credit_in[10])
   ,.EN_recv_ports_10_putCredits(send_credit[10])

   ,.EN_recv_ports_11_getFlit(1'b1)
   ,.recv_ports_11_getFlit(flit_out[11])
   ,.recv_ports_11_putCredits_cr_in(credit_in[11])
   ,.EN_recv_ports_11_putCredits(send_credit[11])
   
   ,.EN_recv_ports_12_getFlit(1'b1)
   ,.recv_ports_12_getFlit(flit_out[12])
   ,.recv_ports_12_putCredits_cr_in(credit_in[12])
   ,.EN_recv_ports_12_putCredits(send_credit[12])
   
   ,.EN_recv_ports_13_getFlit(1'b1)
   ,.recv_ports_13_getFlit(flit_out[13])
   ,.recv_ports_13_putCredits_cr_in(credit_in[13])
   ,.EN_recv_ports_13_putCredits(send_credit[13])
   
   ,.EN_recv_ports_14_getFlit(1'b1)
   ,.recv_ports_14_getFlit(flit_out[14])
   ,.recv_ports_14_putCredits_cr_in(credit_in[14])
   ,.EN_recv_ports_14_putCredits(send_credit[14])

 	//receive ports 15-19
   ,.EN_recv_ports_15_getFlit(1'b1)
   ,.recv_ports_15_getFlit(flit_out[15])
   ,.recv_ports_15_putCredits_cr_in(credit_in[15])
   ,.EN_recv_ports_15_putCredits(send_credit[15])

   ,.EN_recv_ports_16_getFlit(1'b1)
   ,.recv_ports_16_getFlit(flit_out[16])
   ,.recv_ports_16_putCredits_cr_in(credit_in[16])
   ,.EN_recv_ports_16_putCredits(send_credit[16])
   
   ,.EN_recv_ports_17_getFlit(1'b1)
   ,.recv_ports_17_getFlit(flit_out[17])
   ,.recv_ports_17_putCredits_cr_in(credit_in[17])
   ,.EN_recv_ports_17_putCredits(send_credit[17])
   
   ,.EN_recv_ports_18_getFlit(1'b1)
   ,.recv_ports_18_getFlit(flit_out[18])
   ,.recv_ports_18_putCredits_cr_in(credit_in[18])
   ,.EN_recv_ports_18_putCredits(send_credit[18])
   
   ,.EN_recv_ports_19_getFlit(1'b1)
   ,.recv_ports_19_getFlit(flit_out[19])
   ,.recv_ports_19_putCredits_cr_in(credit_in[19])
   ,.EN_recv_ports_19_putCredits(send_credit[19])

 	//receive ports 20-24
   ,.EN_recv_ports_20_getFlit(1'b1)
   ,.recv_ports_20_getFlit(flit_out[20])
   ,.recv_ports_20_putCredits_cr_in(credit_in[20])
   ,.EN_recv_ports_20_putCredits(send_credit[20])

   ,.EN_recv_ports_21_getFlit(1'b1)
   ,.recv_ports_21_getFlit(flit_out[21])
   ,.recv_ports_21_putCredits_cr_in(credit_in[21])
   ,.EN_recv_ports_21_putCredits(send_credit[21])
   
   ,.EN_recv_ports_22_getFlit(1'b1)
   ,.recv_ports_22_getFlit(flit_out[22])
   ,.recv_ports_22_putCredits_cr_in(credit_in[22])
   ,.EN_recv_ports_22_putCredits(send_credit[22])
   
   ,.EN_recv_ports_23_getFlit(1'b1)
   ,.recv_ports_23_getFlit(flit_out[23])
   ,.recv_ports_23_putCredits_cr_in(credit_in[23])
   ,.EN_recv_ports_23_putCredits(send_credit[23])
   
   ,.EN_recv_ports_24_getFlit(1'b1)
   ,.recv_ports_24_getFlit(flit_out[24])
   ,.recv_ports_24_putCredits_cr_in(credit_in[24])
   ,.EN_recv_ports_24_putCredits(send_credit[24])
   
   );


endmodule
