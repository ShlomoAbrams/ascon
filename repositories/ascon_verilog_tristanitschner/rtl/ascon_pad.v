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
// * performs padding by adding a one to the last beat
// * input data is masked by us, so it is not required that unused bytes be zero
// * l2_bw = log2(bw) to support different byte widths (saves area)
// * we process the same input data as ascon_aead128 module
// * the original keep is preserved
// * we generate a new last, but preserve the original last, because the
// ciphertext is the same length as the plaintext
// * full little endian implementation

module ascon_pad #( 
	parameter  l2_bw = 3,
	localparam bw    = 1 << l2_bw,
	localparam kw    = 128/bw,
	localparam l2_kw = 128/bw
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
	output wire          m_last_orig,
	output wire          m_skip,
	output wire          m_enc_decn,
	output wire [127:0]  m_data,
	output wire [kw-1:0] m_keep,
	output wire [127:0]  m_nonce,
	output wire          m_ad,
	output wire          m_p
);

// passing these through is not strictly necessary, but that's just my style :)

assign m_enc_decn = s_enc_decn;
assign m_nonce    = s_nonce;
assign m_ad       = s_ad;
assign m_p        = 1; // we always have plaintext, because if there isn't any, we pad it

////////////////////////////////////////////////////////////////////////////////
// state logic
// Note: we could save this state logic, if we would integrate this padding
// logic into the core engine, -- however, then the code would be even more
// unreadable

reg r_first = 1;
reg r_ad    = 0;
reg r_p     = 0;
reg r_t     = 0;

wire [3:0] state = {r_first, r_ad, r_p, r_t};

reg rr_p = 0;
always @(posedge clk) begin
	if (r_first && m_valid && m_ready) begin
		rr_p <= s_p;
	end
end

reg r_enc_decn;
always @(posedge clk) begin
	if (r_first && s_valid && s_ready) begin
		r_enc_decn <= s_enc_decn;
	end
end

always @(posedge clk) begin
	if (m_valid && m_ready) begin
		casez (state)
			4'b1???: begin
				if (s_ad) begin
					r_first <= 0;
					r_ad <= 1;
				end else begin
					r_first <= 0;
					r_p <= 1;
				end
			end
			4'b?1??: begin
				if (m_last) begin
					r_ad <= 0;
					r_p <= 1;
				end
			end
			4'b??1?: begin
				if (m_last) begin
					r_p <= 0;
					if (r_enc_decn) begin
						r_first <= 1;
					end else begin
						r_t <= 1;
					end
				end
			end
			4'b???1: begin
				r_t     <= 0;
				r_first <= 1;
			end
		endcase
	end
end

////////////////////////////////////////////////////////////////////////////////
// padding logic

wire needs_extra_beat = (((r_ad || r_p) && s_last && &(s_keep)) || (r_first && !s_ad && !s_p));

reg r_extra = 0;

always @(posedge clk) begin
	if (s_valid && s_ready && needs_extra_beat) begin
		r_extra <= 1;
	end
	if (m_valid && m_ready && r_extra) begin
		r_extra <= 0;
	end
end

function [l2_kw:0] countones (input [kw-1:0] keep);
	integer i;
	begin
		countones = 0;
		for (i = 0; i < kw; i = i + 1) begin
			if (keep[i]) begin
				countones = countones + 1;
			end
		end
	end
endfunction

wire [l2_kw-1:0] keep_adjusted = r_t ? {kw{1'b1}} : s_keep;

wire [l2_kw:0] keepcount = countones(keep_adjusted);

function [127:0] mask_data(input [127:0] data, input [kw-1:0] keep);
	integer i;
	begin
		mask_data = 0;
		for (i = 0; i < kw; i = i + 1) begin
			if (keep[i]) begin
				mask_data[bw*(i+1)-1-:bw] = data[bw*(i+1)-1-:bw];
			end
		end
	end
endfunction

wire [127:0] data_masked = mask_data(s_data, keep_adjusted);

wire [127:0] data_extended = data_masked | (1 << (bw*keepcount));

wire pad_empty_plaintext = r_p && !rr_p;

wire extra = r_extra || pad_empty_plaintext;

assign m_valid = s_valid || extra;
assign s_ready = m_ready && !extra;

localparam [127:0] extra_beat = 1;

assign m_data      = extra ? extra_beat : data_extended;
assign m_keep      = extra ? 0          : s_keep;
assign m_last      = (s_last && !needs_extra_beat) || extra;
assign m_last_orig = s_last;
assign m_skip      = extra;

`ifdef FORMAL

	always @(posedge clk) begin
		assert($onehot(state));
	end

`endif /* FORMAL */

endmodule
