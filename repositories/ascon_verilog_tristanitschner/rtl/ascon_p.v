// BSD 4-Clause License
// 
// Copyright (c) 2026, Tristan Itschner
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
// 
// 3. All advertising materials mentioning features or use of this software must
//    display the following acknowledgement:
//      This product includes software developed by Tristan Itschner.
// 
// 4. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDER "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL COPYRIGHT HOLDER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

`default_nettype none
`timescale 1 ns / 1 ps

// Notes:
// * s_rnd is the total number of rounds to be performed - 1
// * you can specify the number of round the core should perform in one cycle
// (so you can properly adapt it to your timing / area needs)
// * mixed endian implementation (as is usual with ciphers)

module ascon_p #(
	parameter rounds_per_clk = 1
) (
	input  wire clk,

	input  wire         s_valid,
	output wire         s_ready,
	input  wire [319:0] s_data,
	input  wire [3:0]   s_rnd,

	output wire         m_valid,
	input  wire         m_ready,
	output wire [319:0] m_data
);

genvar gi;

reg [3:0] r_rnd;
always @(posedge clk) begin
	if (s_valid && s_ready) begin
		r_rnd <= s_rnd;
	end
end

reg r_running = 0;
always @(posedge clk) begin
	if (m_valid && m_ready) begin
		r_running <= 0;
	end
	if (s_valid && s_ready) begin
		r_running <= 1;
	end
end

wire do_something = r_running && !(m_valid && !m_ready);

wire [3:0] current_round_indices [0:rounds_per_clk-1];

wire counter_last;
wire [3:0] counter; // necessary for formal
generate if (rounds_per_clk == 1) begin : gen_count_downwards
	// use downcounting counter for better timing

	reg [3:0] counter_down = 0;

	wire counter_down_last = !(|(counter_down));

	always @(posedge clk) begin
		if (do_something) begin
			counter_down <= counter_down - 1;
		end
		if (s_valid && s_ready) begin
			counter_down <= s_rnd;
		end
	end

	assign current_round_indices[0] = r_rnd - 15 - (r_rnd - counter_down);

	assign counter = counter_down;
	assign counter_last = counter_down_last;

end else begin : gen_count_upwards
	// another critical timing path is the issue anyways

	reg [3:0] counter_up = 0;

	wire counter_up_last = counter_up + rounds_per_clk > r_rnd;

	always @(posedge clk) begin
		if (do_something) begin
			if (counter_up_last) begin
				counter_up <= 0;
			end else begin
				counter_up <= counter_up + rounds_per_clk;
			end
		end
	end

	for (gi = 0; gi < rounds_per_clk; gi = gi + 1) begin
		assign current_round_indices[gi] = r_rnd - 15 - (counter_up + gi);
	end 

	assign counter = counter_up;
	assign counter_last = counter_up_last;

end endgenerate

wire [319:0] S [0:rounds_per_clk];

generate for (gi = 0; gi < rounds_per_clk; gi = gi + 1) begin

	ascon_round ascon_ronud_inst (
		.clk   (clk),
		.i     (current_round_indices[gi]),
		.S_in  (S[gi]),
		.S_out (S[gi+1])
	);

end endgenerate

wire [3:0] last_round_mod = (r_rnd+1) % rounds_per_clk;

reg [319:0] r_state;
always @(posedge clk) begin
	if (s_valid && s_ready) begin
		r_state <= s_data;
	end else begin
		if (do_something) begin
			r_state <= S[rounds_per_clk];
		end
	end
end

assign S[0] = r_state;

assign s_ready = !r_running || (m_valid && m_ready);
assign m_valid = r_running && counter_last;
assign m_data = S[last_round_mod == 0 ? rounds_per_clk : last_round_mod];

`ifdef FORMAL

	reg r_match0 = 0;
	reg r_match1 = 0;

	always @(posedge clk) begin
		if(s_valid && s_ready) begin
			r_match0 <= 0;
			r_match1 <= 0;
			if(s_data == 320'h00001000808c000107060504030201000f0e0d0c0b0a090817161514131211101f1e1d1c1b1a1918
					&& s_rnd == 12-1) begin
				r_match0 <= 1;
			end
			if (s_data == 320'hcde34900cdfce3f8948cba141a58c1cb1fec9b5dae69b43a65039cf8da2adaac323c9da505d9b927
					&& s_rnd == 8-1) begin
				r_match1 <= 1;
			end

		end
	end

	always @(posedge clk) begin
		if (m_valid && r_match0) begin
			assert(m_data == 320'hcde34900cdfce2c8948cba141a58c1cb1fec9b5dae69b43a620599fcd928dbac3d3290a90ed3b02f);
		end
	end

	generate if (rounds_per_clk == 1) begin : gen_match0_individual_tests

		always @(posedge clk) begin
			if (r_running && r_match0) begin
				case (counter) 
					11-0:  assert(S[1] == 320'h6542b06eabd55b523631a1235df002c33fffffffffffff743c38900488a461b31c1c1c1c1c1c1c1c);
					11-1:  assert(S[1] == 320'h1a9782200fefc521fc9e629734c65a5c9af7ad12003bb18d87a77ecec424f0f0f6a7c23d78226f12);
					11-2:  assert(S[1] == 320'h2840cb7fdc686b2c88030547a386de4766fbb2af254c166e3f890015ee0bb5e40593812a884c017e);
					11-3:  assert(S[1] == 320'h82e964b9a92694d91c51c7d03713df8ca5db7a87302c68549a3d3e596330a24b9b8c53a5f193a79c);
					11-4:  assert(S[1] == 320'h758c5225ed9605a314ca89422691be6af91056866dc3e6b087e4d1677e625af725f03e8263485a1b);
					11-5:  assert(S[1] == 320'h4361c7484f82283a563d7212f31fbc1c0be75ddc81a1e2d25088bc8aae913df1a945d7a82002bcd8);
					11-6:  assert(S[1] == 320'h9b070caad00eb06567247a58aea7a41c32fd58d50dd7bdfe856f9e4f7450e2881e00e776e4475a63);
					11-7:  assert(S[1] == 320'h9fe7f6b4d6fc6c6363a31a3654aea2728ef57892b9bea27e7cc095fa916843d58230af351178783e);
					11-8:  assert(S[1] == 320'h3609d9524ba18dca2df1a0ef2d001991de970a2c63cbdb6fcaaabd6ce30f1976732185c487d484e6);
					11-9:  assert(S[1] == 320'h18e5cc2935e35a3b8aed8c6aa0083ac083a21e341dc177fbb018ce1b46e483c2f2dac03647989757);
					11-10: assert(S[1] == 320'h909e60eb8f3777ee9edd0104fe8431cd409a92f1f7b54f54add39fb0baedda414e46354210dfdf1e);
					11-11: assert(S[1] == 320'hcde34900cdfce2c8948cba141a58c1cb1fec9b5dae69b43a620599fcd928dbac3d3290a90ed3b02f);
					default: assert(0); // unreachable
				endcase
			end
		end

	end endgenerate

	always @(posedge clk) begin
		if (m_valid && r_match1) begin
			assert(m_data == 320'hbd74820da95f31b6e9cd32f3ec9768514e22649820f75165badaec61762fca512316ddb9e9f20395);
		end
	end

	generate if (rounds_per_clk == 1) begin : gen_match1_individual_tests
		
		always @(posedge clk) begin
			if (r_running && r_match1) begin
				case (counter) 
					7-0:  assert(S[1] == 320'h48f22fdb8674527fb5cfc542aeef699e3068bf14242800cbb0556581dade50fce77780ea139b2adb);
					7-1:  assert(S[1] == 320'hc212328b5c788debb73ecad79f8c7f4c1332ef35c3f584fa3064ede2e435ddd2a917d6de2e204599);
					7-2:  assert(S[1] == 320'h21202d548f6e8515ea9e9cd5f9301a2de0db2f217be31eaefec57e259a4a26d05c706b0a98982881);
					7-3:  assert(S[1] == 320'h55ec3db07053271f2e9a03df86a70549649942b5c69479c8b8322650e8ab46a5070e93bb8b17a586);
					7-4:  assert(S[1] == 320'h26ffce842b7c268e272d633af7bc85d7f943f81d1847538e09b1d991e9c8f1064bb172a428184bf5);
					7-5:  assert(S[1] == 320'hf3780060d532824211c90cc70d6027d1abd7a099e85e622d3f188c879acf6b16b93b0fe25082baf7);
					7-6:  assert(S[1] == 320'h780281621dd6316ce89da3d5479de682443471e2f2cabb4e1714d0c263129b0044e5d2cdd34218cd);
					7-7:  assert(S[1] == 320'hbd74820da95f31b6e9cd32f3ec9768514e22649820f75165badaec61762fca512316ddb9e9f20395);
					default: assert(0); // unreachable
				endcase
			end
		end

	end endgenerate

	always @(posedge clk) begin
		cover(m_valid && r_match0);
		cover(m_valid && r_match1);
	end

`endif /* FORMAL */

endmodule
