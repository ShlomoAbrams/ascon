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
// * the main ascon_aead128 engine
// * in contrast to ascon_aead128_core, here we support padding
// * note though that the output data is not padded, that logic has been moved
// to the axis core and is not guaranteed by the core engine anymore

module ascon_aead128 #(
	parameter rounds_per_clk    = 1,
	parameter l2_bw             = 7,
	parameter decouple_pad2core = 1,
`ifdef FORMAL
	parameter formal_testcase          = 500,
	parameter formal_enc_decn          = 1,
	parameter formal_testcases_enabled = 0,
`endif /* FORMAL */
	localparam bw = 1 << l2_bw,
	localparam kw = 128/bw
) (
	input wire clk,

	input  wire          s_valid,
	output wire          s_ready,
	input  wire          s_last,
	input  wire          s_enc_decn,
	input  wire [127:0]  s_data,
	input  wire [kw-1:0] s_keep,
	input  wire [127:0]  s_nonce,
	input  wire          s_ad,
	input  wire          s_p,

	output wire          m_valid,
	input  wire          m_ready,
	output wire          m_last,
	output wire          m_enc_decn,
	output wire [127:0]  m_data,
	output wire [kw-1:0] m_keep,
	output wire          m_ad,
	output wire          m_p,
	output wire          m_t
);

wire          pad_m_valid;
wire          pad_m_ready;
wire          pad_m_last;
wire          pad_m_last_orig;
wire          pad_m_skip;
wire          pad_m_enc_decn;
wire [127:0]  pad_m_data;
wire [kw-1:0] pad_m_keep;
wire [127:0]  pad_m_nonce;
wire          pad_m_ad;
wire          pad_m_p;

ascon_pad #( 
	.l2_bw (l2_bw)
) ascon_pad_inst (
	.clk         (clk),
	.s_valid     (s_valid),
	.s_ready     (s_ready),
	.s_last      (s_last),
	.s_enc_decn  (s_enc_decn),
	.s_data      (s_data),
	.s_keep      (s_keep),
	.s_nonce     (s_nonce),
	.s_ad        (s_ad),
	.s_p         (s_p),
	.m_valid     (pad_m_valid),
	.m_ready     (pad_m_ready),
	.m_last      (pad_m_last),
	.m_last_orig (pad_m_last_orig),
	.m_skip      (pad_m_skip),
	.m_enc_decn  (pad_m_enc_decn),
	.m_data      (pad_m_data),
	.m_keep      (pad_m_keep),
	.m_nonce     (pad_m_nonce),
	.m_ad        (pad_m_ad),
	.m_p         (pad_m_p)
);

// swap to my mixed endianess

wire [127:0] pad_m_data_swapped = {pad_m_data [63:0], pad_m_data [127:64]};

wire [kw-1:0] pad_m_keep_swapped;

generate if (kw == 1) begin : gen_pad_m_keep_kw1
	assign pad_m_keep_swapped = pad_m_keep;
end else begin : gen_pad_m_keep_kw_other
	assign pad_m_keep_swapped = {pad_m_keep [kw/2-1-:kw/2], pad_m_keep [kw-1-:kw/2]};
end endgenerate

wire [127:0] pad_m_nonce_swapped = {pad_m_nonce [63:0], pad_m_nonce [127:64]};

wire [127:0]  core_m_data;
wire [kw-1:0] core_m_keep;

wire          rs_m_valid;
wire          rs_m_ready;
wire          rs_m_last;
wire          rs_m_last_orig;
wire          rs_m_skip;
wire          rs_m_enc_decn;
wire [127:0]  rs_m_data;
wire [kw-1:0] rs_m_keep;
wire [127:0]  rs_m_nonce;
wire          rs_m_ad;
wire          rs_m_p;

ascon_isolator #(
	.dw     (1 + 1 + 1 + 1 + 128 + kw + 128 + 1 + 1),
	.enable (decouple_pad2core)
) ascon_isolator_inst (
	.clk     (clk),
	.s_valid (pad_m_valid),
	.s_ready (pad_m_ready),
	.s_data  ({
		pad_m_last,
		pad_m_last_orig,
		pad_m_skip,
		pad_m_enc_decn,
		pad_m_data_swapped,
		pad_m_keep_swapped,
		pad_m_nonce_swapped,
		pad_m_ad,
		pad_m_p
	}),
	.m_valid (rs_m_valid),
	.m_ready (rs_m_ready),
	.m_data  ({
		rs_m_last,
		rs_m_last_orig,
		rs_m_skip,
		rs_m_enc_decn,
		rs_m_data,
		rs_m_keep,
		rs_m_nonce,
		rs_m_ad,
		rs_m_p
	})
);

ascon_aead128_core #(
	.rounds_per_clk (rounds_per_clk),
	.l2_bw          (l2_bw)
) ascon_aead128_core_inst (
	.clk         (clk),
	.s_valid     (rs_m_valid),
	.s_ready     (rs_m_ready),
	.s_last      (rs_m_last),
	.s_last_orig (rs_m_last_orig),
	.s_skip      (rs_m_skip),
	.s_enc_decn  (rs_m_enc_decn),
	.s_data      (rs_m_data),
	.s_keep      (rs_m_keep),
	.s_nonce     (rs_m_nonce),
	.s_ad        (rs_m_ad),
	.s_p         (rs_m_p),
	.m_valid     (m_valid),
	.m_ready     (m_ready),
	.m_last      (m_last),
	.m_enc_decn  (m_enc_decn),
	.m_data      (core_m_data),
	.m_keep      (core_m_keep),
	.m_ad        (m_ad),
	.m_p         (m_p),
	.m_t         (m_t)
);

// swap back

wire [127:0] core_m_data_swapped = {core_m_data [63:0], core_m_data [127:64]};

wire [kw-1:0] core_m_keep_swapped;

generate if (kw == 1) begin : gen_m_keep_kw1
	assign core_m_keep_swapped = core_m_keep;
end else begin : gen_m_keep_kw_other
	assign core_m_keep_swapped = {core_m_keep [kw/2-1-:kw/2], core_m_keep [kw-1-:kw/2]};
end endgenerate

assign m_data = core_m_data_swapped;
assign m_keep = core_m_keep_swapped;

`ifdef FORMAL

	generate if (formal_testcases_enabled != 0) begin : gen_formal_param_assertions
		always @(posedge clk) begin
			assert(l2_bw == 3); // a byte must be 8 bits for our formal testcases
		end
	end endgenerate

	always @(posedge clk) begin
		if (m_valid) begin
			assert($onehot({m_ad, m_p, m_t}));
			if (m_t) begin
				assert(m_keep == {kw{1'b1}});
			end
		end
	end

	////////////////////////////////////////////////////////////////////////
	// the generic stuff for the generated formal KAT tests

	always @(posedge clk) begin
		if (m_valid && m_t) begin
			assert(m_last);
		end
	end

	reg [31:0] s_counter = 0;
	wire t_s_last;
	always @(posedge clk) begin
		if (s_valid && s_ready) begin
			if (t_s_last) begin
				s_counter <= 0;
			end else begin
				s_counter <= s_counter + 1;
			end
		end
	end

	reg [31:0] m_counter = 0;
	wire t_m_last;
	always @(posedge clk) begin
		if (m_valid && m_ready) begin
			if (t_m_last) begin
				m_counter <= 0;
			end else begin
				m_counter <= m_counter + 1;
			end
		end
	end

	function [127:0] byteswap128(input [127:0] x);
		integer i;
		begin
			for (i = 0; i < 16; i = i + 1) begin
				byteswap128[8*(i+1)-1-:8] = x[8*(16-i)-1-:8];
			end
		end
	endfunction

	function [127:0] transform(input [127:0] x);
		transform = byteswap128(x);
	endfunction

	function [15:0] bitswap16(input [15:0] x);
		integer i;
		begin
			for (i = 0; i < 16; i = i + 1) begin
				bitswap16[i] = x[15-i];
			end
		end
	endfunction

	function [15:0] transform_keep(input [15:0] x);
		transform_keep = bitswap16(x);
	endfunction

	function [127:0] rotr128(input [127:0] x, input integer shamt);
		rotr128 = (x << (128-shamt)) | (x >> shamt);
	endfunction

`include "ascon_aead128_formal_testcases.v"

	////////////////////////////////////////////////////////////////////////
	// cover

	wire tag_happens = m_valid && m_ready && m_last && m_t;

	always @(posedge clk) begin
		cover(tag_happens);
	end

	// properties for forward progress -> must reach at least two packets
	reg tag_happened = 0;
	always @(posedge clk) begin
		if (tag_happens) begin
			tag_happened <= 1;
		end
	end

	always @(posedge clk) begin
		cover(tag_happened && tag_happens);
	end


	// AXI compliance
	always @(posedge clk) begin
		cover(m_valid && !m_ready);
	end

`endif /* FORMAL */

endmodule
