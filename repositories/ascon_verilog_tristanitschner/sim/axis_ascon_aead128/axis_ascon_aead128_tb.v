`default_nettype none
`timescale 1 ns / 1 ps

module axis_ascon_aead128_tb;

parameter debug_trace = 0;
parameter debug_text  = 1;

initial begin
    if (debug_trace) begin
        $dumpfile("axis_ascon_aead128_tb.vcd");
        $dumpvars(0, axis_ascon_aead128_tb);
    end
end

reg clk = 1;
initial forever #1 clk = !clk;

initial begin
	#10000000
	$finish;
end

parameter rounds_per_clk     = 5;
parameter keep_support       = 1;
parameter input_isolator     = 1;
parameter output_isolator    = 1;
parameter formal_fifo_cmd_aw = 4;
parameter formal_fifo_ad_aw  = 4;
parameter formal_fifo_d_aw   = 4;

////////////////////////////////////////////////////////////////////////////////

wire           enc_s_cmd_tvalid;
wire           enc_s_cmd_tready;
wire [511:0]   enc_s_cmd_tdata;
wire           enc_s_ad_tvalid;
wire           enc_s_ad_tready;
wire           enc_s_ad_tlast;
wire [127:0]   enc_s_ad_tdata;
wire [15:0]    enc_s_ad_tkeep;
wire           enc_s_tag_tvalid;
wire           enc_s_tag_tready;
wire [127:0]   enc_s_tag_tdata;
wire           enc_s_tvalid;
wire           enc_s_tready;
wire           enc_s_tlast;
wire [127:0]   enc_s_tdata;
wire [15:0]    enc_s_tkeep;
wire           enc_m_ad_tvalid;
wire           enc_m_ad_tready;
wire           enc_m_ad_tlast;
wire [127:0]   enc_m_ad_tdata;
wire [15:0]    enc_m_ad_tkeep;
wire           enc_m_tvalid;
wire           enc_m_tready;
wire           enc_m_tlast;
wire [127:0]   enc_m_tdata;
wire [15:0]    enc_m_tkeep;
wire           enc_m_tag_tvalid;
wire           enc_m_tag_tready;
wire [127:0]   enc_m_tag_tdata;

axis_ascon_aead128 #(
	.rounds_per_clk  (rounds_per_clk),
	.keep_support    (keep_support),
	.input_isolator  (input_isolator),
	.output_isolator (output_isolator)
) axis_ascon_aead128_inst_enc (
	.clk          (clk),
	.s_cmd_tvalid (enc_s_cmd_tvalid),
	.s_cmd_tready (enc_s_cmd_tready),
	.s_cmd_tdata  (enc_s_cmd_tdata),
	.s_ad_tvalid  (enc_s_ad_tvalid),
	.s_ad_tready  (enc_s_ad_tready),
	.s_ad_tlast   (enc_s_ad_tlast),
	.s_ad_tdata   (enc_s_ad_tdata),
	.s_ad_tkeep   (enc_s_ad_tkeep),
	.s_tag_tvalid (enc_s_tag_tvalid),
	.s_tag_tready (enc_s_tag_tready),
	.s_tag_tdata  (enc_s_tag_tdata),
	.s_tvalid     (enc_s_tvalid),
	.s_tready     (enc_s_tready),
	.s_tlast      (enc_s_tlast),
	.s_tdata      (enc_s_tdata),
	.s_tkeep      (enc_s_tkeep),
	.m_ad_tvalid  (enc_m_ad_tvalid),
	.m_ad_tready  (enc_m_ad_tready),
	.m_ad_tlast   (enc_m_ad_tlast),
	.m_ad_tdata   (enc_m_ad_tdata),
	.m_ad_tkeep   (enc_m_ad_tkeep),
	.m_tvalid     (enc_m_tvalid),
	.m_tready     (enc_m_tready),
	.m_tlast      (enc_m_tlast),
	.m_tdata      (enc_m_tdata),
	.m_tkeep      (enc_m_tkeep),
	.m_tag_tvalid (enc_m_tag_tvalid),
	.m_tag_tready (enc_m_tag_tready),
	.m_tag_tdata  (enc_m_tag_tdata)
);

////////////////////////////////////////////////////////////////////////////////

wire         dec_s_cmd_tvalid;
wire         dec_s_cmd_tready;
wire [511:0] dec_s_cmd_tdata;
wire         dec_s_ad_tvalid;
wire         dec_s_ad_tready;
wire         dec_s_ad_tlast;
wire [127:0] dec_s_ad_tdata;
wire [15:0]  dec_s_ad_tkeep;
wire         dec_s_tag_tvalid;
wire         dec_s_tag_tready;
wire [127:0] dec_s_tag_tdata;
wire         dec_s_tvalid;
wire         dec_s_tready;
wire         dec_s_tlast;
wire [127:0] dec_s_tdata;
wire [15:0]  dec_s_tkeep;
wire         dec_m_ad_tvalid;
wire         dec_m_ad_tready;
wire         dec_m_ad_tlast;
wire [127:0] dec_m_ad_tdata;
wire [15:0]  dec_m_ad_tkeep;
wire         dec_m_tvalid;
wire         dec_m_tready;
wire         dec_m_tlast;
wire [127:0] dec_m_tdata;
wire [15:0]  dec_m_tkeep;
wire         dec_m_tag_tvalid;
wire         dec_m_tag_tready;
wire [127:0] dec_m_tag_tdata;

axis_ascon_aead128 #(
	.rounds_per_clk  (rounds_per_clk),
	.keep_support    (keep_support),
	.input_isolator  (input_isolator),
	.output_isolator (output_isolator)
) axis_ascon_aead128_inst_dec (
	.clk          (clk),
	.s_cmd_tvalid (dec_s_cmd_tvalid),
	.s_cmd_tready (dec_s_cmd_tready),
	.s_cmd_tdata  (dec_s_cmd_tdata),
	.s_ad_tvalid  (dec_s_ad_tvalid),
	.s_ad_tready  (dec_s_ad_tready),
	.s_ad_tlast   (dec_s_ad_tlast),
	.s_ad_tdata   (dec_s_ad_tdata),
	.s_ad_tkeep   (dec_s_ad_tkeep),
	.s_tag_tvalid (dec_s_tag_tvalid),
	.s_tag_tready (dec_s_tag_tready),
	.s_tag_tdata  (dec_s_tag_tdata),
	.s_tvalid     (dec_s_tvalid),
	.s_tready     (dec_s_tready),
	.s_tlast      (dec_s_tlast),
	.s_tdata      (dec_s_tdata),
	.s_tkeep      (dec_s_tkeep),
	.m_ad_tvalid  (dec_m_ad_tvalid),
	.m_ad_tready  (dec_m_ad_tready),
	.m_ad_tlast   (dec_m_ad_tlast),
	.m_ad_tdata   (dec_m_ad_tdata),
	.m_ad_tkeep   (dec_m_ad_tkeep),
	.m_tvalid     (dec_m_tvalid),
	.m_tready     (dec_m_tready),
	.m_tlast      (dec_m_tlast),
	.m_tdata      (dec_m_tdata),
	.m_tkeep      (dec_m_tkeep),
	.m_tag_tvalid (dec_m_tag_tvalid),
	.m_tag_tready (dec_m_tag_tready),
	.m_tag_tdata  (dec_m_tag_tdata)
);

//////////////////////////////////////////////////////////////////////////////// 
// drive input with random data

reg           r_enc_s_cmd_tvalid = 0;
reg [511:0]   r_enc_s_cmd_tdata;
reg           r_enc_s_ad_tvalid = 0;
reg           r_enc_s_ad_tlast;
reg [127:0]   r_enc_s_ad_tdata;
reg [15:0]    r_enc_s_ad_tkeep;
reg           r_enc_s_tag_tvalid = 0;
reg [127:0]   r_enc_s_tag_tdata;
reg           r_enc_s_tvalid = 0;
reg           r_enc_s_tlast;
reg [127:0]   r_enc_s_tdata;
reg [15:0]    r_enc_s_tkeep;

always @(posedge clk) begin
	r_enc_s_cmd_tvalid <= $random;
	r_enc_s_cmd_tdata  <= {$random, $random, $random, $random, $random, $random, $random, $random,
			       $random, $random, $random, $random, $random, $random, $random, $random};
	r_enc_s_ad_tvalid  <= $random;
	r_enc_s_ad_tlast   <= $random;
	r_enc_s_ad_tdata   <= {$random, $random, $random, $random};
	r_enc_s_ad_tkeep   <= $random;
	r_enc_s_tag_tvalid <= $random;
	r_enc_s_tag_tdata  <= {$random, $random, $random, $random};
	r_enc_s_tvalid     <= $random;
	r_enc_s_tlast      <= $random;
	r_enc_s_tdata      <= {$random, $random, $random, $random};
	r_enc_s_tkeep      <= $random;
end

wire enc_s_cmd_stall;

function [15:0] make_valid_keep(input [15:0] keep);
	reg found;
	integer i;
	begin
		found = 0;
		make_valid_keep = 1;
		for (i = 0; i < 16; i = i + 1) begin
			if (!found) begin
				if (keep[15-i]) begin
					found = 1;
					make_valid_keep[15-i] = 1;
				end
			end else begin
				make_valid_keep[15-i] = 1;
			end

		end
	end
endfunction

assign enc_s_cmd_tvalid = r_enc_s_cmd_tvalid && !enc_s_cmd_stall;
assign enc_s_cmd_tdata  = {r_enc_s_cmd_tdata[511:257], 1'b1, r_enc_s_cmd_tdata[255:0]}; // always encode
assign enc_s_ad_tvalid  = r_enc_s_ad_tvalid;
assign enc_s_ad_tlast   = r_enc_s_ad_tlast;
assign enc_s_ad_tdata   = r_enc_s_ad_tdata;
assign enc_s_ad_tkeep   = enc_s_ad_tlast ? make_valid_keep(r_enc_s_ad_tkeep) : -1;
assign enc_s_tag_tvalid = r_enc_s_tag_tvalid;
assign enc_s_tag_tdata  = r_enc_s_tag_tdata;
assign enc_s_tvalid     = r_enc_s_tvalid;
assign enc_s_tlast      = r_enc_s_tlast;
assign enc_s_tdata      = r_enc_s_tdata;
assign enc_s_tkeep      = enc_s_tlast ? make_valid_keep(r_enc_s_tkeep) : -1;

//////////////////////////////////////////////////////////////////////////////// 
// direct connection from enc to dec

formal_fifo #(
	.aw (formal_fifo_ad_aw),
	.dw (1 + 128 + 16)
) formal_fifo_inst_ad (
	.clk     (clk),
	.s_valid (enc_m_ad_tvalid),
	.s_ready (enc_m_ad_tready),
	.s_data  ({
		enc_m_ad_tlast,
		enc_m_ad_tdata,
		enc_m_ad_tkeep
	}),
	.m_valid (dec_s_ad_tvalid),
	.m_ready (dec_s_ad_tready),
	.m_data  ({
		dec_s_ad_tlast,
		dec_s_ad_tdata,
		dec_s_ad_tkeep
	})
);

formal_fifo #(
	.aw (formal_fifo_ad_aw),
	.dw (1 + 128 + 16)
) formal_fifo_inst_p (
	.clk     (clk),
	.s_valid (enc_m_tvalid),
	.s_ready (enc_m_tready),
	.s_data  ({
		enc_m_tlast,
		enc_m_tdata,
		enc_m_tkeep
	}),
	.m_valid (dec_s_tvalid),
	.m_ready (dec_s_tready),
	.m_data  ({
		dec_s_tlast,
		dec_s_tdata,
		dec_s_tkeep
	})
);

formal_fifo #(
	.aw (formal_fifo_cmd_aw),
	.dw (128)
) formal_fifo_inst_tag (
	.clk     (clk),
	.s_valid (enc_m_tag_tvalid),
	.s_ready (enc_m_tag_tready),
	.s_data  (enc_m_tag_tdata),
	.m_valid (dec_s_tag_tvalid),
	.m_ready (dec_s_tag_tready),
	.m_data  (dec_s_tag_tdata)
);

always @(posedge clk) begin
	// we always encode, so this is not possible
	assert(!enc_s_tag_tready);
end

//////////////////////////////////////////////////////////////////////////////// 
// fifo enc cmd in -> dec cmd in

wire         fc_s_cmd_tvalid;
wire         fc_s_cmd_tready;
wire [511:0] fc_s_cmd_tdata;
wire         fc_m_cmd_tvalid;
wire         fc_m_cmd_tready;
wire [511:0] fc_m_cmd_tdata;

formal_fifo #(
	.aw (formal_fifo_cmd_aw),
	.dw (512)
) formal_fifo_inst_cmd (
	.clk     (clk),
	.s_valid (fc_s_cmd_tvalid),
	.s_ready (fc_s_cmd_tready),
	.s_data  (fc_s_cmd_tdata),
	.m_valid (fc_m_cmd_tvalid),
	.m_ready (fc_m_cmd_tready),
	.m_data  (fc_m_cmd_tdata)
);

assign fc_s_cmd_tvalid = enc_s_cmd_tvalid && enc_s_cmd_tready;
assign fc_s_cmd_tdata  = enc_s_cmd_tdata;

always @(posedge clk) begin
	if (!fc_s_cmd_tready) begin
		assume(!enc_s_cmd_tvalid);
	end
end

assign dec_s_cmd_tvalid = fc_m_cmd_tvalid;
assign fc_m_cmd_tready = dec_s_cmd_tready;
assign dec_s_cmd_tdata = {fc_m_cmd_tdata[511:257], 1'b0, fc_m_cmd_tdata[255:0]}; // always decode

assign enc_s_cmd_stall = !fc_s_cmd_tready;

////////////////////////////////////////////////////////////////////////////////

reg r_dec_m_ad_tready  = 0;
reg r_dec_m_tready     = 0;
reg r_dec_m_tag_tready = 0;

always @(posedge clk) begin
	r_dec_m_ad_tready  <= $random;
	r_dec_m_tready     <= $random;
	r_dec_m_tag_tready <= $random;
end

assign dec_m_ad_tready  = r_dec_m_ad_tready;
assign dec_m_tready     = r_dec_m_tready;
assign dec_m_tag_tready = r_dec_m_tag_tready;

////////////////////////////////////////////////////////////////////////////////
// check tag

always @(posedge clk) begin
	if (dec_m_tag_tvalid) begin
		assert(dec_m_tag_tdata == 0);
	end
end

wire error_sig = dec_m_tag_tvalid && dec_m_tag_tdata != 0;

////////////////////////////////////////////////////////////////////////////////
// cover

reg [31:0] tags_received = 0;
always @(posedge clk) begin
	if (dec_m_tag_tvalid && dec_m_tag_tready) begin
		tags_received <= tags_received + 1;
	end
end

reg [31:0] tag_errors = 0;

always @(posedge clk) begin
	if (dec_m_tag_tvalid && dec_m_tag_tready) begin
		if (dec_m_tag_tdata == 0) begin
			// display something, so we know the testbench is making
			// forward progress
			$display("Nr. %d: Verified TAG successfully! :D", tags_received);
		end else begin
			tag_errors <= tag_errors + 1;
		end
	end
end

final begin
	$display("Verified %d tags. No ERRORS above? -> ALL GOOD :D", tags_received);
	$display("There were %d ERRORS in total.", tag_errors);
end

////////////////////////////////////////////////////////////////////////////////
// record io data

generate if (debug_text) begin : dump_io_data

	integer s_fp;
	initial s_fp = $fopen("s_plaintext.txt", "w");

	always @(posedge clk) begin
		if (enc_s_tvalid && enc_s_tready) begin
			$fwrite(s_fp, "%016x %016b\n", enc_s_tdata, enc_s_tkeep);
			if (enc_s_tlast) begin
				$fwrite(s_fp, "LAST\n");
			end
		end
	end

	integer m_fp;
	initial m_fp = $fopen("m_plaintext.txt", "w");

	always @(posedge clk) begin
		if (dec_m_tvalid && dec_m_tready) begin
			$fwrite(m_fp, "%016x %016b\n", dec_m_tdata, dec_m_tkeep);
			if (dec_m_tlast) begin
				$fwrite(m_fp, "LAST\n");
			end
		end
	end

	integer s_ad_fp;
	initial s_ad_fp = $fopen("s_ad.txt", "w");

	always @(posedge clk) begin
		if (enc_s_ad_tvalid && enc_s_ad_tready) begin
			$fwrite(s_ad_fp, "%016x %016b\n", enc_s_ad_tdata, enc_s_ad_tkeep);
			if (enc_s_ad_tlast) begin
				$fwrite(s_ad_fp, "LAST\n");
			end
		end
	end

	integer m_ad_fp;
	initial m_ad_fp = $fopen("m_ad.txt", "w");

	always @(posedge clk) begin
		if (dec_m_ad_tvalid && dec_m_ad_tready) begin
			$fwrite(m_ad_fp, "%016x %016b\n", dec_m_ad_tdata, dec_m_ad_tkeep);
			if (dec_m_ad_tlast) begin
				$fwrite(m_ad_fp, "LAST\n");
			end
		end
	end

end endgenerate

endmodule
