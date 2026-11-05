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
// * just a standard isolator

module ascon_isolator #(
	parameter dw     = 32,
	parameter enable = 1
) (
	input wire clk,

	input  wire          s_valid,
	output wire          s_ready,
	input  wire [dw-1:0] s_data,

	output wire          m_valid,
	input  wire          m_ready,
	output wire [dw-1:0] m_data
);

wire          i_valid;
wire          i_ready;
wire [dw-1:0] i_data;

generate if (enable) begin : gen_isolator

	ascon_skidbuffer #(
		.dw (dw)
	) ascon_skidbuffer_inst (
		.clk     (clk),
		.s_valid (s_valid),
		.s_ready (s_ready),
		.s_data  (s_data),
		.m_valid (i_valid),
		.m_ready (i_ready),
		.m_data  (i_data)
	);

	ascon_regslice #(
		.dw (dw)
	) ascon_regslice_inst (
		.clk     (clk),
		.s_valid (i_valid),
		.s_ready (i_ready),
		.s_data  (i_data),
		.m_valid (m_valid),
		.m_ready (m_ready),
		.m_data  (m_data)
	);

end else begin : gen_passthrough
	
	assign m_valid = s_valid;
	assign s_ready = m_ready;
	assign m_data  = s_data;

end endgenerate

endmodule
