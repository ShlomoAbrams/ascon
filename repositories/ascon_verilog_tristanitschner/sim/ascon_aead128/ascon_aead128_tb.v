`default_nettype none
`timescale 1 ns / 1 ps

module ascon_aead128_tb;

parameter debug_trace = 1;

initial begin
    if (debug_trace) begin
        $dumpfile("ascon_aead128_tb.vcd");
        $dumpvars(0, ascon_aead128_tb);
    end
end

reg clk = 1;
initial forever #1 clk = !clk;

initial begin
	#10000
	$finish;
end

parameter rounds_per_clk = 4;
parameter l2_bw          = 3;
localparam bw = 1 << l2_bw;
localparam kw = 128/bw;

wire          s_valid;
wire          s_ready;
wire          s_last;
wire          s_enc_decn;
wire [127:0]  s_data;
wire [kw-1:0] s_keep;
wire [127:0]  s_nonce;
wire          s_ad;
wire          s_p;

wire          m_valid;
wire          m_ready;
wire          m_last;
wire          m_enc_decn;
wire [127:0]  m_data;
wire [kw-1:0] m_keep;
wire          m_ad;
wire          m_p;
wire          m_t;

ascon_aead128 #(
	.rounds_per_clk (rounds_per_clk),
	.l2_bw          (l2_bw)
) ascon_aead128_inst (
	.clk (clk),
	.s_valid    (s_valid),
	.s_ready    (s_ready),
	.s_last     (s_last),
	.s_enc_decn (s_enc_decn),
	.s_data     (s_data),
	.s_keep     (s_keep),
	.s_nonce    (s_nonce),
	.s_ad       (s_ad),
	.s_p        (s_p),
	.m_valid    (m_valid),
	.m_ready    (m_ready),
	.m_last     (m_last),
	.m_enc_decn (m_enc_decn),
	.m_data     (m_data),
	.m_keep     (m_keep),
	.m_ad       (m_ad),
	.m_p        (m_p),
	.m_t        (m_t)
);

reg          r_s_valid    = 0;
reg          r_s_ready    = 0;
reg          r_s_last     = 0;
reg          r_s_enc_decn = 0;
reg [127:0]  r_s_data     = 0;
reg [kw-1:0] r_s_keep     = 0;
reg [127:0]  r_s_nonce    = 0;
reg          r_s_ad       = 0;
reg          r_s_p        = 0;

always @(posedge clk) begin
	r_s_valid    <= $random;
	r_s_last     <= $random;
	r_s_enc_decn <= $random;
	r_s_data     <= $random;
	r_s_keep     <= $random;
	r_s_nonce    <= $random;
	r_s_ad       <= $random;
	r_s_p        <= $random;
end

assign s_valid    = r_s_valid;
assign s_last     = r_s_last;
assign s_enc_decn = r_s_enc_decn;
assign s_data     = r_s_data;
assign s_keep     = r_s_keep;
assign s_nonce    = r_s_nonce;
assign s_ad       = r_s_ad;
assign s_p        = r_s_p;

reg r_m_ready = 0;
always @(posedge clk) begin
	r_m_ready <= $random;
end

assign m_ready = r_m_ready;

endmodule
