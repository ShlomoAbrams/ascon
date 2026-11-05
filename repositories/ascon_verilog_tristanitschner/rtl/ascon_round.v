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

// Description:
// * one round of ascorn
// * mixed endian implementation (as usual with ciphers)

// rnd -- total number of rounds
// i   -- inverted current round

module ascon_round (
    input wire clk, // dummy

    input wire [3:0] i,

    input  wire [319:0] S_in,
    output wire [319:0] S_out
);

genvar gi;

////////////////////////////////////////////////////////////////////////////////

wire [63:0] S [0:4];
generate for (gi = 0; gi < 5; gi = gi + 1) begin
    assign S[gi] = S_in[64*(5-gi)-1-:64]; // big endian
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// constant addition layer

wire [63:0] c_lut [0:15];
assign c_lut[0]  = 64'h000000000000003c;
assign c_lut[1]  = 64'h000000000000002d;
assign c_lut[2]  = 64'h000000000000001e;
assign c_lut[3]  = 64'h000000000000000f;
assign c_lut[4]  = 64'h00000000000000f0;
assign c_lut[5]  = 64'h00000000000000e1;
assign c_lut[6]  = 64'h00000000000000d2;
assign c_lut[7]  = 64'h00000000000000c3;
assign c_lut[8]  = 64'h00000000000000b4;
assign c_lut[9]  = 64'h00000000000000a5;
assign c_lut[10] = 64'h0000000000000096;
assign c_lut[11] = 64'h0000000000000087;
assign c_lut[12] = 64'h0000000000000078;
assign c_lut[13] = 64'h0000000000000069;
assign c_lut[14] = 64'h000000000000005a;
assign c_lut[15] = 64'h000000000000004b;

wire [63:0] c = c_lut[16-i];

wire [63:0] S0 [0:4];
generate for (gi = 0; gi < 5; gi = gi + 1) begin

    if (gi == 2) begin : gen_S02
        assign S0[gi] = S[gi] ^ c;
    end else begin : gen_S0x
        assign S0[gi] = S[gi];
    end

end endgenerate

////////////////////////////////////////////////////////////////////////////////
// substitution layer

function [4:0] sbox (input [4:0] x);
    begin
        sbox[0] = x[4]&x[1] ^ x[3]      ^ x[2]&x[1] ^ x[2]      ^ x[1]&x[0] ^ x[1] ^ x[0];
        sbox[1] = x[4]      ^ x[3]&x[2] ^ x[3]&x[1] ^ x[3]      ^ x[2]&x[1] ^ x[2] ^ x[1] ^ x[0];
        sbox[2] = x[4]&x[3] ^ x[4]      ^ x[2]      ^ x[1]      ^ 1;
        sbox[3] = x[4]&x[0] ^ x[4]      ^ x[3]&x[0] ^ x[3]      ^ x[2]      ^ x[1] ^ x[0];
        sbox[4] = x[4]&x[1] ^ x[4]      ^ x[3]      ^ x[1]&x[0] ^ x[1];
    end
endfunction

wire [63:0] S1 [0:4];

generate for (gi = 0; gi < 64; gi = gi + 1) begin
	assign {S1[4][gi], S1[3][gi], S1[2][gi], S1[1][gi], S1[0][gi]} =
	 sbox ({S0[4][gi], S0[3][gi], S0[2][gi], S0[1][gi], S0[0][gi]});
end endgenerate

////////////////////////////////////////////////////////////////////////////////
// linear diffusion layer

wire [63:0] S2 [0:4];

function [63:0] rotr(input [63:0] x, input integer shamt);
	rotr = (x << (64-shamt)) | (x >> shamt);
endfunction

assign S2[0] = S1[0] ^ rotr(S1[0], 19) ^ rotr(S1[0], 28);
assign S2[1] = S1[1] ^ rotr(S1[1], 61) ^ rotr(S1[1], 39);
assign S2[2] = S1[2] ^ rotr(S1[2], 1)  ^ rotr(S1[2], 6);
assign S2[3] = S1[3] ^ rotr(S1[3], 10) ^ rotr(S1[3], 17);
assign S2[4] = S1[4] ^ rotr(S1[4], 7)  ^ rotr(S1[4], 41);

////////////////////////////////////////////////////////////////////////////////

generate for (gi = 0; gi < 5; gi = gi + 1) begin
    assign S_out[64*(5-gi)-1-:64] = S2[gi]; // big endian
end endgenerate

////////////////////////////////////////////////////////////////////////////////

`ifdef FORMAL

	reg [31:0] timestamp = 0;
	always @(posedge clk) begin
		timestamp <= timestamp + 1;
	end 

	always @(posedge clk) begin
		cover(timestamp == 10);
	end

	always @(posedge clk) begin
		assume(i == 11);
		assume(S[0] == 64'h6542b06eabd55b52);
		assume(S[1] == 64'h3631a1235df002c3);
		assume(S[2] == 64'h3fffffffffffff74);
		assume(S[3] == 64'h3c38900488a461b3);
		assume(S[4] == 64'h1c1c1c1c1c1c1c1c);
	end

	// round constant
	always @(posedge clk) begin
		assert(S0[0] == 64'h6542b06eabd55b52);
		assert(S0[1] == 64'h3631a1235df002c3);
		assert(S0[2] == 64'h3fffffffffffff95);
		assert(S0[3] == 64'h3c38900488a461b3);
		assert(S0[4] == 64'h1c1c1c1c1c1c1c1c);
	end

	// substitution layer
	always @(posedge clk) begin
		assert(S1[0] == 64'h56957fb7c94ec774);
		assert(S1[1] == 64'h7291d38d4096b838);
		assert(S1[2] == 64'hf635ad3b49e81ea5);
		assert(S1[3] == 64'h6ca8e2a21df282a9);
		assert(S1[4] == 64'h26058d19dc887d2e);
	end

	// round output
	always @(posedge clk) begin
		assert(S2[0] == 64'h1a9782200fefc521);
		assert(S2[1] == 64'hfc9e629734c65a5c);
		assert(S2[2] == 64'h9af7ad12003bb18d);
		assert(S2[3] == 64'h87a77ecec424f0f0);
		assert(S2[4] == 64'hf6a7c23d78226f12);
	end

`endif /* FORMAL */

endmodule
