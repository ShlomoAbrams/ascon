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

// Input format is as follows:
// * first beat is key in s_data and s_nonce evaluated
// 	* they are latched, so they are allowed to change after the first beat
// * s_last should be be set on first beat
// * the core then expects two further packets, where the first packet is the
// associated data and the the plaintext / ciphertext
// * if the core is instructed to decode, it also expects a third tag input
// packet (tag in data)
// * both packets must have been padded appropriately, however the keep signal
// is still necessary for proper masking of the output (don't spill any internal
// state)
// * the core outputs then three packets, the first being the associated data
// (for routing purposes, makes no sense not to pass it on in hardware, and it
// is rather easy to throw away, if you really don't need it) and the second
// the ciphertext, the third is the tag
// * for decode, the third packet is the plaintext and the third has data ==
// 0 if the tag matches
// * mixed endian implementation (as is usual with ciphers)
// * the core keep must be full on first beat and on tag input beat

// TODO: module that properly (= aligned) inserts the tag
// 	-> is it really worth it? -> NO
// TODO: optimize that one pause cycle on back to back
// 	-> no that breaks timing due to congestion...

module ascon_aead128_core #(
	parameter  rounds_per_clk = 6,
	parameter  l2_bw          = 3,
	localparam bw             = 1 << l2_bw,
	localparam kw             = 128/bw
) (
	input wire clk,

	input  wire          s_valid,
	output wire          s_ready,
	input  wire          s_last,
	input  wire          s_last_orig,
	input  wire          s_skip,
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

////////////////////////////////////////////////////////////////////////////////

wire         ap_s_valid;
wire         ap_s_ready;
wire [319:0] ap_s_data;
wire [3:0]   ap_s_rnd;
wire         ap_m_valid;
wire         ap_m_ready;
wire [319:0] ap_m_data;

ascon_p #(
	.rounds_per_clk (rounds_per_clk)
) ascon_p_inst (
	.clk     (clk),
	.s_valid (ap_s_valid),
	.s_ready (ap_s_ready),
	.s_data  (ap_s_data),
	.s_rnd   (ap_s_rnd),
	.m_valid (ap_m_valid),
	.m_ready (ap_m_ready),
	.m_data  (ap_m_data)
);

////////////////////////////////////////////////////////////////////////////////

// the state signals
reg r_first = 1;
reg r_ad    = 0; // associated data
reg r_p     = 0; // plain text
reg r_final = 0; // tag

wire [3:0] state = {r_first, r_ad, r_p, r_final};

reg [127:0] r_key;
always @(posedge clk) begin
	if (s_valid && s_ready && r_first) begin
		r_key <= s_data;
	end
end

reg r_enc_decn;
always @(posedge clk) begin
	if (r_first && s_valid && s_ready) begin
		r_enc_decn <= s_enc_decn;
	end
end

reg rr_first = 0;
always @(posedge clk) begin
	if (ap_s_valid && ap_s_ready) begin
		rr_first <= r_first;
	end
end

reg rr_p;
always @(posedge clk) begin
	if (r_first && s_valid && s_ready) begin
		rr_p <= s_p;
	end
end

reg r_ds; // domain seperation, sideband
always @(posedge clk) begin
	if (s_valid && s_ready) begin
		if (r_first && !s_ad) begin
			r_ds <= 1;
		end else if (r_ad && s_last) begin
			r_ds <= 1;
		end else begin
			r_ds <= 0;
		end
	end
end

always @(posedge clk) begin
	if (s_valid && s_ready) begin
		casez (state)
			4'b1???: begin
				r_first <= 0;
				if (s_ad) begin
					r_ad <= 1;
				end else begin
					r_p <= 1;
				end
			end
			4'b?1??: begin
				if (s_last) begin
					r_ad <= 0;
					if (rr_p) begin
						r_p <= 1;
					end else begin
						r_final <= 1;
					end
				end
			end
			4'b??1?: begin
				if (s_last) begin
					r_p <= 0;
					r_final <= 1;
				end
			end
		endcase
	end
	if (m_valid && m_ready && r_final) begin
		r_final <= 0;
		r_first <= 1;
	end
end

////////////////////////////////////////////////////////////////////////////////
// main logic

localparam [63:0] iv = 64'h00001000808c0001;

wire [319:0] ap_m_data_second_key = rr_first ? ap_m_data ^ {192'b0, r_key} : ap_m_data;

wire [63:0] sep_word = ap_m_data_second_key[63:0] ^ (1 << 63);

wire [319:0] ap_m_data_ds = r_ds ? {ap_m_data_second_key[319:64], sep_word} : ap_m_data_second_key;

wire [319:0] ap_m_data_xored = ap_m_data_ds ^ ({192'b0, s_data} << 192);

function [127:0] overwrite_data(input [127:0] data, input [127:0] other_data, input [kw-1:0] keep);
	integer i;
	begin
		overwrite_data = 0;
		for (i = 0; i < kw; i = i + 1) begin
			if (keep[i]) begin
				overwrite_data[bw*(i+1)-1-:bw] = data[bw*(i+1)-1-:bw];
			end else begin
				overwrite_data[bw*(i+1)-1-:bw] = other_data[bw*(i+1)-1-:bw];
			end
		end
	end
endfunction

wire [127:0] ap_m_data_overwritten = overwrite_data(s_data, ap_m_data_xored[319:192], s_keep);

wire [319:0] ap_m_data_xored2 =
	r_enc_decn              ? ap_m_data_xored : 
	(!r_enc_decn && s_last) ? {ap_m_data_overwritten, ap_m_data_xored[191:0]} : 
				  {s_data, ap_m_data_xored[191:0]};

reg [319:0] c_ap_s_data; /* wire */
always @(*) begin
	casez (state)
		4'b1???: c_ap_s_data = {iv, s_data, s_nonce};
		4'b?1??: c_ap_s_data = ap_m_data_xored;
		4'b??1?: begin
			c_ap_s_data = ap_m_data_xored2;
			if (s_last) begin
				c_ap_s_data = {ap_m_data_xored2[319:192], 
					r_key ^ ap_m_data_xored2[191:64], ap_m_data_xored2[63:0]};
			end
		end 
		default: c_ap_s_data = 320'hx;
	endcase
end
assign ap_s_data = c_ap_s_data;

localparam a = 12;
localparam b = 8;

reg [3:0] c_ap_s_rnd; /* wire */
always @(*) begin
	c_ap_s_rnd = 4'hx;
	casez (state)
		4'b1???: c_ap_s_rnd = a-1;
		4'b?1??: c_ap_s_rnd = b-1;
		4'b??1?: begin
			c_ap_s_rnd = b-1;
			if (s_last) begin
				c_ap_s_rnd = a-1;
			end
		end
	endcase
end
assign ap_s_rnd = c_ap_s_rnd;

wire stall = m_valid && !m_ready;

wire skip_empty = s_skip && s_valid && (r_ad || r_p);

// well this is a little convoluted...
assign ap_s_valid = s_valid && !stall && !r_final;
assign ap_m_ready = r_final ? (r_enc_decn ? m_ready : (m_ready && s_valid)) : 
			      ((m_ready && m_valid) || skip_empty);
assign s_ready = (r_first || (!stall && (r_enc_decn ? !r_final : 1))) && ap_s_ready;
assign m_valid = r_final ? (r_enc_decn ? ap_m_valid : (ap_m_valid && s_valid)) 
			 : (ap_m_valid && s_valid && !skip_empty) && !r_first;

wire [127:0] data_out = ap_m_data[127:0] ^ r_key;

assign m_data = r_final ? (r_enc_decn ? data_out : (data_out ^ s_data)) 
			: r_ad ? s_data : ap_m_data[319:192] ^ s_data;
assign m_keep = r_final ? {kw{1'b1}} : s_keep;
assign m_last = r_final || s_last_orig;

////////////////////////////////////////////////////////////////////////////////
// the output sideband signals

assign m_ad       = r_ad;
assign m_p        = r_p;
assign m_t        = r_final;
assign m_enc_decn = r_enc_decn;

////////////////////////////////////////////////////////////////////////////////

`ifdef FORMAL

	always @(posedge clk) begin
		assert($onehot(state));
	end

	always @(posedge clk) begin
		if (m_valid && m_t) begin
			assert(&(m_keep));
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

	function [63:0] byteswap64(input [63:0] x);
		integer i;
		begin
			for (i = 0; i < 8; i = i + 1) begin
				byteswap64[8*(i+1)-1-:8] = x[8*(8-i)-1-:8];
			end
		end
	endfunction

	function [127:0] transform(input [127:0] x);
		transform = {byteswap64(x[127:64]), byteswap64(x[63:0])};
	endfunction

	generate if (0) begin : gen_formal_enc

		always @(posedge clk) begin
			assume(s_enc_decn);
		end

		// our testcase
		//  k[16]= {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f}
		//  n[16]= {0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f}
		//  a[32]= {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 
		//          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f}
		//  m[32]= {0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 
		//          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f}
		//  c[32]= {0xcb, 0x34, 0xd0, 0x46, 0x60, 0xa6, 0x6d, 0xbf, 0xbe, 0x9c, 0x85, 0x66, 0x01, 0xf5, 0xb8, 0xaa, 
		//          0x51, 0xa4, 0x99, 0xb5, 0x5a, 0xc8, 0xf7, 0xfb, 0xef, 0xbc, 0x33, 0x1a, 0x61, 0x3e, 0xe9, 0xcd}
		//  t[16]= {0xfd, 0x19, 0x17, 0x50, 0xa4, 0x7f, 0x21, 0x1c, 0x0a, 0x15, 0xed, 0x28, 0x17, 0x3d, 0x7c, 0xaa}

		wire [127:0] t_key    = transform(128'h000102030405060708090a0b0c0d0e0f);
		wire [127:0] t_nonce  = transform(128'h101112131415161718191a1b1c1d1e1f);
		wire [127:0] t_ad0    = transform(128'h303132333435363738393a3b3c3d3e3f);
		wire [127:0] t_ad1    = transform(128'h404142434445464748494a4b4c4d4e4f);
		wire [127:0] t_ad_pad = transform(128'h01000000000000000000000000000000);
		wire [127:0] t_m0     = transform(128'h202122232425262728292a2b2c2d2e2f);
		wire [127:0] t_m1     = transform(128'h303132333435363738393a3b3c3d3e3f);
		wire [127:0] t_m_pad  = transform(128'h01000000000000000000000000000000);
		wire [127:0] t_c0     = transform(128'hcb34d04660a66dbfbe9c856601f5b8aa);
		wire [127:0] t_c1     = transform(128'h51a499b55ac8f7fbefbc331a613ee9cd);
		wire [127:0] t_t      = transform(128'hfd191750a47f211c0a15ed28173d7caa);

		reg [31:0] ap_s_counter = 0;
		always @(posedge clk) begin
			if (ap_s_valid && ap_s_ready) begin
				ap_s_counter <= ap_s_counter + 1;
			end
		end

		wire [319:0] ap_s1 = 320'h00001000808c000107060504030201000f0e0d0c0b0a090817161514131211101f1e1d1c1b1a1918;
		wire [319:0] ap_s2 = 320'hfad57c34feced3f8abb287282162f8f31fec9b5dae69b43a65039cf8da2adaac323c9da505d9b927;
		wire [319:0] ap_s3 = 320'h4bd451919fe2fb37931a76f1633711bea3fda970c0ce9ec0c11c9b9e9b31f936c1a75de00b87cd01;
		wire [319:0] ap_s4 = 320'h65f66d9ecce313cbebb2dfc7eb8faf33c84b273ca1da2038bbeab9421418590a15d69d76b2033547;
		wire [319:0] ap_s5 = 320'hbf6da66046d034cbaab8f50166859cbeee90d4f02f821cb24c64b5053b820bb665979decab4386ea;
		wire [319:0] ap_s6 = 320'hfbf7c85ab599a451cde93e611a33bcefc350a5094259578e9632075bef6edd8ee58ecc0db597a5ce;
		wire [319:0] ap_s7 = 320'hf195a1302d8ff6a449aca2976db3dcaaa24fa24791a74ab0ee7801f4a985529ddc4e68db5abbc4a8;

		wire [319:0] ap_s1_diff = ap_s1 - ap_s_data;
		wire [319:0] ap_s2_diff = ap_s2 - ap_s_data;
		wire [319:0] ap_s3_diff = ap_s3 - ap_s_data;
		wire [319:0] ap_s4_diff = ap_s4 - ap_s_data;
		wire [319:0] ap_s5_diff = ap_s5 - ap_s_data;
		wire [319:0] ap_s6_diff = ap_s6 - ap_s_data;
		wire [319:0] ap_s7_diff = ap_s7 - ap_s_data;

		always @(posedge clk) begin
			if (ap_s_valid && ap_s_ready) begin
				case (ap_s_counter)
					0: assert(ap_s1_diff == 0);
					1: assert(ap_s2_diff == 0);
					2: assert(ap_s3_diff == 0);
					3: assert(ap_s4_diff == 0);
					4: assert(ap_s5_diff == 0);
					5: assert(ap_s6_diff == 0);
					6: assert(ap_s7_diff == 0);
				endcase
			end
		end

		always @(posedge clk) begin
			assume(s_nonce == t_nonce);
			assume(s_ad && s_p);
		end

		always @(posedge clk) begin
			case (s_counter)
				1: assume(s_keep == {kw{1'b1}});
				2: assume(s_keep == {kw{1'b1}});
				3: assume(s_keep == {kw{1'b0}});
				4: assume(s_keep == {kw{1'b1}});
				5: assume(s_keep == {kw{1'b1}});
				6: assume(s_keep == {kw{1'b0}});
			endcase
		end

		always @(posedge clk) begin
			case (s_counter)
				0: assume(s_data == t_key);
				1: assume(s_data == t_ad0);
				2: assume(s_data == t_ad1);
				3: assume(s_data == t_ad_pad);
				4: assume(s_data == t_m0);
				5: assume(s_data == t_m1);
				6: assume(s_data == t_m_pad);
			endcase
		end

		assign t_s_last = s_counter == 6;

		always @(posedge clk) begin
			assume(s_last == (t_s_last || s_counter == 3));
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
		assign t_m_last = m_counter == 4;

		wire [127:0] diff = m_data ^ t_t;

		always @(posedge clk) begin
			if (m_valid) begin
				case (m_counter)
					0: assert(m_data == t_ad0);
					1: assert(m_data == t_ad1);
					2: assert(m_data == t_c0);
					3: assert(m_data == t_c1);
					4: assert(diff == 0);
				endcase
			end
		end

		always @(posedge clk) begin
			if (m_valid) begin
				case (m_counter)
					0: assert(m_ad);
					1: assert(m_ad);
					2: assert(m_p);
					3: assert(m_p);
					4: assert(m_t);
				endcase
			end
		end

	end endgenerate

	generate if (0) begin : gen_formal_dec

		always @(posedge clk) begin
			assume(!s_enc_decn);
		end

		// our testcase
		// k[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f}
		// n[16] = {0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f}
		// a[32] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
		//          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f}
		// c[32] = {0xcb, 0x34, 0xd0, 0x46, 0x60, 0xa6, 0x6d, 0xbf, 0xbe, 0x9c, 0x85, 0x66, 0x01, 0xf5, 0xb8, 0xaa,
		//          0x51, 0xa4, 0x99, 0xb5, 0x5a, 0xc8, 0xf7, 0xfb, 0xef, 0xbc, 0x33, 0x1a, 0x61, 0x3e, 0xe9, 0xcd}
		// t[16] = {0xfd, 0x19, 0x17, 0x50, 0xa4, 0x7f, 0x21, 0x1c, 0x0a, 0x15, 0xed, 0x28, 0x17, 0x3d, 0x7c, 0xaa}
		// m[32] = {0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 
		//          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f}

		wire [127:0] t_key    = transform(128'h000102030405060708090a0b0c0d0e0f);
		wire [127:0] t_nonce  = transform(128'h101112131415161718191a1b1c1d1e1f);
		wire [127:0] t_ad0    = transform(128'h303132333435363738393a3b3c3d3e3f);
		wire [127:0] t_ad1    = transform(128'h404142434445464748494a4b4c4d4e4f);
		wire [127:0] t_ad_pad = transform(128'h01000000000000000000000000000000);
		wire [127:0] t_c0     = transform(128'hcb34d04660a66dbfbe9c856601f5b8aa);
		wire [127:0] t_c1     = transform(128'h51a499b55ac8f7fbefbc331a613ee9cd);
		wire [127:0] t_c_pad  = transform(128'h01000000000000000000000000000000);
		wire [127:0] t_p0     = transform(128'h202122232425262728292a2b2c2d2e2f);
		wire [127:0] t_p1     = transform(128'h303132333435363738393a3b3c3d3e3f);
		wire [127:0] t_t      = transform(128'hfd191750a47f211c0a15ed28173d7caa);

		reg [31:0] ap_s_counter = 0;
		always @(posedge clk) begin
			if (ap_s_valid && ap_s_ready) begin
				ap_s_counter <= ap_s_counter + 1;
			end
		end

		wire [319:0] ap_s1 = 320'h00001000808c000107060504030201000f0e0d0c0b0a090817161514131211101f1e1d1c1b1a1918;
		wire [319:0] ap_s2 = 320'hfad57c34feced3f8abb287282162f8f31fec9b5dae69b43a65039cf8da2adaac323c9da505d9b927;
		wire [319:0] ap_s3 = 320'h4bd451919fe2fb37931a76f1633711bea3fda970c0ce9ec0c11c9b9e9b31f936c1a75de00b87cd01;
		wire [319:0] ap_s4 = 320'h65f66d9ecce313cbebb2dfc7eb8faf33c84b273ca1da2038bbeab9421418590a15d69d76b2033547;
		wire [319:0] ap_s5 = 320'hbf6da66046d034cbaab8f50166859cbeee90d4f02f821cb24c64b5053b820bb665979decab4386ea;
		wire [319:0] ap_s6 = 320'hfbf7c85ab599a451cde93e611a33bcefc350a5094259578e9632075bef6edd8ee58ecc0db597a5ce;
		wire [319:0] ap_s7 = 320'hf195a1302d8ff6a449aca2976db3dcaaa24fa24791a74ab0ee7801f4a985529ddc4e68db5abbc4a8;

		wire [319:0] ap_s1_diff = ap_s1 - ap_s_data;
		wire [319:0] ap_s2_diff = ap_s2 - ap_s_data;
		wire [319:0] ap_s3_diff = ap_s3 - ap_s_data;
		wire [319:0] ap_s4_diff = ap_s4 - ap_s_data;
		wire [319:0] ap_s5_diff = ap_s5 - ap_s_data;
		wire [319:0] ap_s6_diff = ap_s6 - ap_s_data;
		wire [319:0] ap_s7_diff = ap_s7 - ap_s_data;

		always @(posedge clk) begin
			if (ap_s_valid && ap_s_ready) begin
				case (ap_s_counter)
					0: assert(ap_s1_diff == 0);
					1: assert(ap_s2_diff == 0);
					2: assert(ap_s3_diff == 0);
					3: assert(ap_s4_diff == 0);
					4: assert(ap_s5_diff == 0);
					5: assert(ap_s6_diff == 0);
					6: assert(ap_s7_diff == 0);
				endcase
			end
		end

		always @(posedge clk) begin
			assume(s_key   == t_key);
			assume(s_nonce == t_nonce);
			assume(s_ad && s_p);
		end

		always @(posedge clk) begin
			case (s_counter)
				1: assume(s_keep == {kw{1'b1}});
				2: assume(s_keep == {kw{1'b1}});
				3: assume(s_keep == {kw{1'b0}});
				4: assume(s_keep == {kw{1'b1}});
				5: assume(s_keep == {kw{1'b1}});
				6: assume(s_keep == {kw{1'b0}});
			endcase
		end

		always @(posedge clk) begin
			case (s_counter)
				1: assume(s_data == t_ad0);
				2: assume(s_data == t_ad1);
				3: assume(s_data == t_ad_pad);
				4: assume(s_data == t_c0);
				5: assume(s_data == t_c1);
				6: assume(s_data == t_c_pad);
				7: assume(s_data == t_t);
			endcase
		end

		assign t_s_last = s_counter == 7;

		always @(posedge clk) begin
			assume(s_last == (t_s_last || s_counter == 6 || s_counter == 3));
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
		assign t_m_last = m_counter == 4;

		always @(posedge clk) begin
			if (m_valid) begin
				case (m_counter)
					0: assert(m_data == t_ad0);
					1: assert(m_data == t_ad1);
					2: assert(m_data == t_p0);
					3: assert(m_data == t_p1);
					4: assert(m_data == 0); // -> tag match
				endcase
			end
		end

	end endgenerate

	always @(posedge clk) begin
		cover(m_valid && m_ready && m_last && m_t);
	end

	// AXIS compliance
	always @(posedge clk) begin
		cover(!s_valid && s_ready && r_first);
		// these fail, so we are not AXIS compliant, but I can't
		// change it due to the interlock between the output and
		// input stream of ascon_p without sacrificing performance
		// cover(!s_valid && s_ready && r_ad);    // x
		// cover(!s_valid && s_ready && r_p);     // x
		// cover(!s_valid && s_ready && r_final); // x
	end

	// AXIS compliance
	always @(posedge clk) begin
		cover(m_valid && !m_ready && r_ad);
		cover(m_valid && !m_ready && r_p);
		cover(m_valid && !m_ready && r_final);
	end

`endif /* FORMAL */

endmodule
