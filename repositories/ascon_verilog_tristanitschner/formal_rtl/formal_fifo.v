`default_nettype none
`timescale 1 ns / 1 ps

// Description:
// * just a simple fifo with asynchronous reads for our formal selftest

module formal_fifo #(
	parameter aw = 10,
	parameter dw = 32
) (
	input wire clk,
	
	input  wire          s_valid,
	output wire          s_ready,
	input  wire [dw-1:0] s_data,

	output wire          m_valid,
	input  wire          m_ready,
	output wire [dw-1:0] m_data
);

localparam depth = 1 << aw;

integer i;
reg [dw-1:0] mem [0:depth-1];
initial for (i = 0; i < depth; i = i + 1) mem[i] = 0;

reg [aw:0] wptr = 0;
reg [aw:0] rptr = 0;

wire [aw-1:0] waddr = wptr[aw-1:0];
wire [aw-1:0] raddr = rptr[aw-1:0];

wire do_write = s_valid && s_ready;
wire do_read  = m_valid && m_ready;

always @(posedge clk) begin
	if (do_write) begin
		wptr <= wptr + 1;
	end
end

always @(posedge clk) begin
	if (do_read) begin
		rptr <= rptr + 1;
	end
end

always @(posedge clk) begin
	if (do_write) begin
		mem[waddr] <= s_data;
	end
end

assign m_data = mem[raddr];

wire empty = wptr == rptr;
wire full = wptr[aw] != rptr[aw] && waddr == raddr;

assign m_valid = !empty;
assign s_ready = !full;

endmodule
