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

module axis_ascon_aead128 #(
	parameter rounds_per_clk    = 1,
	parameter keep_support      = 1,
	parameter input_isolator    = 1,
	parameter output_isolator   = 1,
	parameter decouple_pad2core = 1
) (
	input wire clk,

	input  wire         s_cmd_tvalid,
	output wire         s_cmd_tready,
	input  wire [511:0] s_cmd_tdata,

	input  wire         s_ad_tvalid,
	output wire         s_ad_tready,
	input  wire         s_ad_tlast,
	input  wire [127:0] s_ad_tdata,
	input  wire [15:0]  s_ad_tkeep,

	input  wire         s_tag_tvalid,
	output wire         s_tag_tready,
	input  wire [127:0] s_tag_tdata,

	input  wire         s_tvalid,
	output wire         s_tready,
	input  wire         s_tlast,
	input  wire [127:0] s_tdata,
	input  wire [15:0]  s_tkeep,

	output wire         m_ad_tvalid,
	input  wire         m_ad_tready,
	output wire         m_ad_tlast,
	output wire [127:0] m_ad_tdata,
	output wire [15:0]  m_ad_tkeep,

	output wire         m_tvalid,
	input  wire         m_tready,
	output wire         m_tlast,
	output wire [127:0] m_tdata,
	output wire [15:0]  m_tkeep,

	output wire         m_tag_tvalid,
	input  wire         m_tag_tready,
	output wire [127:0] m_tag_tdata
);

localparam l2_bw = keep_support ? 3 : 7;
localparam bw    = 1 << l2_bw;
localparam kw    = 128/bw;

wire [127:0] s_cmd_key      = s_cmd_tdata[127:0];
wire [127:0] s_cmd_nonce    = s_cmd_tdata[255:128];
wire         s_cmd_enc_decn = s_cmd_tdata[256];
wire         s_cmd_ad       = s_cmd_tdata[257];
wire         s_cmd_p        = s_cmd_tdata[258];

wire          i_s_valid;
wire          i_s_ready;
wire          i_s_last;
wire          i_s_enc_decn;
wire [127:0]  i_s_data;
wire [kw-1:0] i_s_keep;
wire [127:0]  i_s_nonce;
wire          i_s_ad;
wire          i_s_p;

////////////////////////////////////////////////////////////////////////////////
// state housekeeping

localparam [1:0] st_cmd = 2'b00;
localparam [1:0] st_ad  = 2'b01;
localparam [1:0] st_p   = 2'b10;
localparam [1:0] st_tag = 2'b11;

reg r_cmd_enc_decn;
reg r_cmd_p;
always @(posedge clk) begin
	if (s_cmd_tvalid && s_cmd_tready) begin
		r_cmd_enc_decn <= s_cmd_enc_decn;
		r_cmd_p        <= s_cmd_p;
	end
end

reg [1:0] r_state = st_cmd;
always @(posedge clk) begin
	if (i_s_ready && i_s_valid) begin
		case (r_state)
			st_cmd: begin
				case ({!s_cmd_enc_decn, s_cmd_ad, s_cmd_p})
					3'b000: r_state <= st_cmd;
					3'b001: r_state <= st_p;
					3'b010: r_state <= st_ad;
					3'b011: r_state <= st_ad;
					3'b100: r_state <= st_tag;
					3'b101: r_state <= st_p;
					3'b110: r_state <= st_ad;
					3'b111: r_state <= st_ad;
				endcase
			end
			st_ad: begin
				if (i_s_last) begin
					case ({!r_cmd_enc_decn, r_cmd_p})
						2'b00: r_state <= st_cmd;
						2'b01: r_state <= st_p;
						2'b10: r_state <= st_tag;
						2'b11: r_state <= st_p;
					endcase
				end
			end
			st_p: begin
				if (i_s_last) begin
					if (r_cmd_enc_decn) begin
						r_state <= st_cmd;
					end else begin
						r_state <= st_tag;
					end
				end
			end
			st_tag: begin
				r_state <= st_cmd;
			end
		endcase
	end
end

////////////////////////////////////////////////////////////////////////////////
// mux the inputs

assign i_s_valid = 
	r_state == st_cmd ?    s_cmd_tvalid :
	r_state == st_ad  ?    s_ad_tvalid  :
	r_state == st_p   ?    s_tvalid     :
     /* r_state == st_tag ? */ s_tag_tvalid;

assign i_s_last = r_state == st_cmd || r_state == st_tag || 
	(r_state == st_ad && s_ad_tlast) || (r_state == st_p && s_tlast);

assign i_s_enc_decn = s_cmd_enc_decn;

assign i_s_data = 
	r_state == st_cmd ?    s_cmd_key  :
	r_state == st_ad  ?    s_ad_tdata :
	r_state == st_p   ?    s_tdata    :
     /* r_state == st_tag ? */ s_tag_tdata;

generate if (keep_support) begin : gen_input_keep_support

	assign i_s_keep = 
		(r_state == st_cmd || r_state == st_tag) ?    {kw{1'b1}} :
		r_state == st_ad                         ?    s_ad_tkeep :
		/* r_state == st_p                       ? */ s_tkeep;

end else begin : gen_no_input_keep_support

	assign i_s_keep = 1;

end endgenerate

assign i_s_nonce = s_cmd_nonce;
assign i_s_ad    = s_cmd_ad;
assign i_s_p     = s_cmd_p;

assign s_cmd_tready = r_state == st_cmd && i_s_ready;
assign s_ad_tready  = r_state == st_ad  && i_s_ready;
assign s_tready     = r_state == st_p   && i_s_ready;
assign s_tag_tready = r_state == st_tag && i_s_ready;

////////////////////////////////////////////////////////////////////////////////

wire          is_m_valid;
wire          is_m_ready;
wire          is_m_last;
wire          is_m_enc_decn;
wire [127:0]  is_m_data; // mux the key in data to save some registers
wire [kw-1:0] is_m_keep;
wire [127:0]  is_m_nonce;
wire          is_m_ad;
wire          is_m_p;

ascon_isolator #(
	.dw     (1 + 1 + 128 + kw + 128 + 1 + 1),
	.enable (input_isolator)
) ascon_isolator_inst0 (
	.clk     (clk),
	.s_valid (i_s_valid),
	.s_ready (i_s_ready),
	.s_data  ({
		i_s_last,
		i_s_enc_decn,
		i_s_data,
		i_s_keep,
		i_s_nonce,
		i_s_ad,
		i_s_p
	}),
	.m_valid (is_m_valid),
	.m_ready (is_m_ready),
	.m_data  ({
		is_m_last,
		is_m_enc_decn,
		is_m_data,
		is_m_keep,
		is_m_nonce,
		is_m_ad,
		is_m_p
	})
);

////////////////////////////////////////////////////////////////////////////////

wire          aa_m_valid;
wire          aa_m_ready;
wire          aa_m_last;
wire          aa_m_enc_decn;
wire [127:0]  aa_m_data;
wire [kw-1:0] aa_m_keep;
wire          aa_m_ad;
wire          aa_m_p;
wire          aa_m_t;

ascon_aead128 #(
	.rounds_per_clk    (rounds_per_clk),
	.l2_bw             (l2_bw),
	.decouple_pad2core (decouple_pad2core)
) ascon_aead128_inst1 (
	.clk        (clk),
	.s_valid    (is_m_valid),
	.s_ready    (is_m_ready),
	.s_last     (is_m_last),
	.s_enc_decn (is_m_enc_decn),
	.s_data     (is_m_data),
	.s_keep     (is_m_keep),
	.s_nonce    (is_m_nonce),
	.s_ad       (is_m_ad),
	.s_p        (is_m_p),
	.m_valid    (aa_m_valid),
	.m_ready    (aa_m_ready),
	.m_last     (aa_m_last),
	.m_enc_decn (aa_m_enc_decn),
	.m_data     (aa_m_data),
	.m_keep     (aa_m_keep),
	.m_ad       (aa_m_ad),
	.m_p        (aa_m_p),
	.m_t        (aa_m_t)
);

////////////////////////////////////////////////////////////////////////////////

wire          i_m_valid;
wire          i_m_ready;
wire          i_m_last;
wire          i_m_enc_decn; // unused
wire [127:0]  i_m_data;
wire [kw-1:0] i_m_keep;
wire          i_m_ad;
wire          i_m_p;
wire          i_m_t;

ascon_isolator #(
	.dw     (1 + 1 + 128 + kw + 1 + 1 + 1),
	.enable (output_isolator)
) ascon_isolator_inst (
	.clk     (clk),
	.s_valid (aa_m_valid),
	.s_ready (aa_m_ready),
	.s_data  ({
		aa_m_last,
		aa_m_enc_decn,
		aa_m_data,
		aa_m_keep,
		aa_m_ad,
		aa_m_p,
		aa_m_t
	}),
	.m_valid (i_m_valid),
	.m_ready (i_m_ready),
	.m_data  ({
		i_m_last,
		i_m_enc_decn,
		i_m_data,
		i_m_keep,
		i_m_ad,
		i_m_p,
		i_m_t
	})
);

////////////////////////////////////////////////////////////////////////////////
// don't spill any internal state

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

wire [127:0] i_m_data_masked = mask_data(i_m_data, i_m_keep);

////////////////////////////////////////////////////////////////////////////////
// mux the outputs

assign m_ad_tvalid = i_m_valid && i_m_ad;
assign m_ad_tdata  = i_m_data_masked;
assign m_ad_tlast  = i_m_last;

assign m_tvalid = i_m_valid && i_m_p;
assign m_tdata  = i_m_data_masked;
assign m_tlast  = i_m_last;

generate if (keep_support) begin : gen_output_keep_support
	assign m_ad_tkeep = i_m_keep;
	assign m_tkeep    = i_m_keep;
end else begin : gen_no_output_keep_supportr
	assign m_ad_tkeep = 16'b1111_1111_1111_1111;
	assign m_tkeep    = 16'b1111_1111_1111_1111;
end endgenerate

assign m_tag_tvalid = i_m_valid && i_m_t;
assign m_tag_tdata  = i_m_data_masked;

assign i_m_ready = 
	i_m_ad ?    m_ad_tready :
	i_m_p  ?    m_tready    :
     /* i_m_t  ? */ m_tag_tready;

////////////////////////////////////////////////////////////////////////////////

`ifdef FORMAL

	// Note: isolators must be disabled for our checks, since they cannot
	// deal with buffering
	always @(posedge clk) begin
		assert(input_isolator  == 0);
		assert(output_isolator == 0);
	end

	reg [31:0] commands_in = 0;
	always @(posedge clk) begin
		if (s_cmd_tvalid && s_cmd_tready) begin
			commands_in <= commands_in + 1;
		end
	end

	reg [31:0] ad_packets_declared = 0;
	always @(posedge clk) begin
		if (s_cmd_tvalid && s_cmd_tready && s_cmd_ad) begin
			ad_packets_declared <= ad_packets_declared + 1;
		end
	end

	reg [31:0] p_packets_declared = 0;
	always @(posedge clk) begin
		if (s_cmd_tvalid && s_cmd_tready && s_cmd_p) begin
			p_packets_declared <= p_packets_declared + 1;
		end
	end

	reg [31:0] tag_packets_declared = 0;
	always @(posedge clk) begin
		if (s_cmd_tvalid && s_cmd_tready && (s_cmd_enc_decn == 0)) begin
			tag_packets_declared <= tag_packets_declared + 1;
		end
	end

	reg [31:0] ad_packets_in = 0;
	always @(posedge clk) begin
		if (s_ad_tvalid && s_ad_tready && s_ad_tlast) begin
			ad_packets_in <= ad_packets_in + 1;
		end
	end

	reg [31:0] data_packets_in = 0;
	always @(posedge clk) begin
		if (s_tvalid && s_tready && s_tlast) begin
			data_packets_in <= data_packets_in + 1;
		end
	end

	reg [31:0] tags_in = 0;
	always @(posedge clk) begin
		if (s_tag_tvalid && s_tag_tready) begin
			tags_in <= tags_in + 1;
		end
	end

	reg [31:0] ad_packets_out = 0;
	always @(posedge clk) begin
		if (m_ad_tvalid && m_ad_tready && m_ad_tlast) begin
			ad_packets_out <= ad_packets_out + 1;
		end
	end

	reg [31:0] data_packets_out = 0;
	always @(posedge clk) begin
		if (m_tvalid && m_tready && m_tlast) begin
			data_packets_out <= data_packets_out + 1;
		end
	end

	reg [31:0] tags_out = 0;
	always @(posedge clk) begin
		if (m_tag_tvalid && m_tag_tready) begin
			tags_out <= tags_out + 1;
		end
	end

	always @(posedge clk) begin
		if (s_cmd_tready) begin
			assert(commands_in     == tags_out);
			assert(ad_packets_in   == ad_packets_out);
			assert(data_packets_in == data_packets_out);
			assert(tags_in         == tag_packets_declared);
			assert(ad_packets_in   == ad_packets_declared);
			assert(data_packets_in == p_packets_declared);
		end
	end

`endif /* FORMAL */

endmodule
