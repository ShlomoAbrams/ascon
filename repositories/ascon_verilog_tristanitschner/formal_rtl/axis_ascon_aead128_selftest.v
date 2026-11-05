`default_nettype none
`timescale 1 ns / 1 ps

// Description:
// * the idea is simple: use two cipher instances, encode with the first, and
// decode with the second, this must always succeed if no error is introduced
// TODO:
// * add support for introducing errors

module axis_ascon_aead128_selftest #(
	parameter rounds_per_clk     = 8,
	parameter keep_support       = 1,
	parameter input_isolator     = 1,
	parameter output_isolator    = 1,
	parameter decouple_pad2core  = 1,
	parameter formal_fifo_cmd_aw = 1,
	parameter formal_fifo_ad_aw  = 1,
	parameter formal_fifo_d_aw   = 1
) (
	input wire clk
);

integer i;

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
	.rounds_per_clk    (rounds_per_clk),
	.keep_support      (keep_support),
	.input_isolator    (input_isolator),
	.output_isolator   (output_isolator),
	.decouple_pad2core (decouple_pad2core)
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
	.rounds_per_clk    (rounds_per_clk),
	.keep_support      (keep_support),
	.input_isolator    (input_isolator),
	.output_isolator   (output_isolator),
	.decouple_pad2core (decouple_pad2core)
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
// direct connection from enc to dec

assign dec_s_ad_tvalid = enc_m_ad_tvalid;
assign enc_m_ad_tready = dec_s_ad_tready;
assign dec_s_ad_tlast  = enc_m_ad_tlast;
assign dec_s_ad_tdata  = enc_m_ad_tdata;
assign dec_s_ad_tkeep  = enc_m_ad_tkeep;

assign dec_s_tvalid = enc_m_tvalid;
assign enc_m_tready = dec_s_tready;
assign dec_s_tlast  = enc_m_tlast;
assign dec_s_tdata  = enc_m_tdata;
assign dec_s_tkeep  = enc_m_tkeep;

assign dec_s_tag_tvalid = enc_m_tag_tvalid;
assign enc_m_tag_tready = dec_s_tag_tready;
assign dec_s_tag_tdata  = enc_m_tag_tdata;

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

always @(posedge clk) begin
	// always encode
	assume(enc_s_cmd_tdata[256]);
end

// swap the enc / dec command bit
assign dec_s_cmd_tdata = {fc_m_cmd_tdata[511:257], !fc_m_cmd_tdata[256], fc_m_cmd_tdata[255:0]};

// assumptions for valid keep
function is_valid_keep(input [15:0] keep, input last);
	reg first_one_found;
	reg is_valid;
	integer i;
	begin
		first_one_found = 0;
		is_valid = 1;
		if (!last) begin
			is_valid_keep = keep == {16{1'b1}};
		end else begin
			for (i = 0; i < 16; i = i + 1) begin
				if (!first_one_found) begin
					if (keep[15-i]) begin
						first_one_found = 1;
					end
				end else begin
					is_valid = is_valid && keep[15-i];
				end
			end
			is_valid_keep = is_valid;
		end
	end
endfunction

always @(posedge clk) begin
	assume(is_valid_keep(enc_s_ad_tkeep, enc_s_ad_tlast));
	assume(is_valid_keep(enc_s_tkeep,    enc_s_tlast));
end

////////////////////////////////////////////////////////////////////////////////
// fifo enc ad in -> dec ad out

wire           fad_s_tvalid;
wire           fad_s_tready;
wire           fad_s_tlast;
wire [127:0]   fad_s_tdata;
wire [15:0]    fad_s_tkeep;

wire           fad_m_tvalid;
wire           fad_m_tready;
wire           fad_m_tlast;
wire [127:0]   fad_m_tdata;
wire [15:0]    fad_m_tkeep;


formal_fifo #(
	.aw (formal_fifo_ad_aw),
	.dw (1 + 128 + 16)
) formal_fifo_inst_ad (
	.clk     (clk),
	.s_valid (fad_s_tvalid),
	.s_ready (fad_s_tready),
	.s_data  ({
		fad_s_tlast,
		fad_s_tdata,
		fad_s_tkeep
	}),
	.m_valid (fad_m_tvalid),
	.m_ready (fad_m_tready),
	.m_data  ({
		fad_m_tlast,
		fad_m_tdata,
		fad_m_tkeep
	})
);

assign fad_s_tvalid = enc_s_ad_tvalid && enc_s_ad_tready;
assign fad_s_tlast  = enc_s_ad_tlast;
assign fad_s_tdata  = enc_s_ad_tdata;
assign fad_s_tkeep  = enc_s_ad_tkeep;

always @(posedge clk) begin
	if (enc_s_ad_tvalid) begin
		assume(enc_s_ad_tkeep != 0);
	end
end

always @(posedge clk) begin
	if (!fad_s_tready) begin
		assume(!enc_s_ad_tvalid);
	end
end

assign fad_m_tready = dec_m_ad_tvalid && dec_m_ad_tready;

always @(posedge clk) begin
	if (!(fad_m_tvalid && dec_m_ad_tvalid)) begin
		assume(!dec_m_ad_tready);
		assume(!fad_m_tready);
	end
end

always @(posedge clk) begin
	if (fad_m_tvalid && dec_m_ad_tvalid) begin
		assert(fad_m_tlast == dec_m_ad_tlast);
		for (i = 0; i < 16; i = i + 1) begin
			if (fad_m_tkeep[i]) begin
				assert(fad_m_tdata[8*(i+1)-1-:8] == dec_m_ad_tdata[8*(i+1)-1-:8]);
			end else begin
				assert(dec_m_ad_tdata[8*(i+1)-1-:8] == 0);
			end
		end
		assert(fad_m_tkeep == dec_m_ad_tkeep);
	end
end

////////////////////////////////////////////////////////////////////////////////
// fifo enc p in -> dec p out

wire           fd_s_tvalid;
wire           fd_s_tready;
wire           fd_s_tlast;
wire [127:0]   fd_s_tdata;
wire [15:0]    fd_s_tkeep;

wire           fd_m_tvalid;
wire           fd_m_tready;
wire           fd_m_tlast;
wire [127:0]   fd_m_tdata;
wire [15:0]    fd_m_tkeep;

formal_fifo #(
	.aw (formal_fifo_d_aw),
	.dw (1 + 128 + 16)
) formal_fifo_inst_d (
	.clk     (clk),
	.s_valid (fd_s_tvalid),
	.s_ready (fd_s_tready),
	.s_data  ({
		fd_s_tlast,
		fd_s_tdata,
		fd_s_tkeep
	}),
	.m_valid (fd_m_tvalid),
	.m_ready (fd_m_tready),
	.m_data  ({
		fd_m_tlast,
		fd_m_tdata,
		fd_m_tkeep
	})
);

assign fd_s_tvalid = enc_s_tvalid && enc_s_tready;
assign fd_s_tlast  = enc_s_tlast;
assign fd_s_tdata  = enc_s_tdata;
assign fd_s_tkeep  = enc_s_tkeep;

always @(posedge clk) begin
	if (enc_s_tvalid) begin
		assume(enc_s_tkeep != 0);
	end
end

always @(posedge clk) begin
	if (!fd_s_tready) begin
		assume(!enc_s_tvalid);
	end
end

assign fd_m_tready = dec_m_tvalid && dec_m_tready;

always @(posedge clk) begin
	if (!(fd_m_tvalid && dec_m_tvalid)) begin
		assume(!dec_m_tready);
		assume(!fd_m_tready);
	end
	if (fd_m_tvalid && dec_m_tvalid) begin
		assert(fd_m_tlast == dec_m_tlast);
		for (i = 0; i < 16; i = i + 1) begin
			if (fd_m_tkeep[i]) begin
				assert(fd_m_tdata[8*(i+1)-1-:8] == dec_m_tdata[8*(i+1)-1-:8]);
			end else begin
				assert(dec_m_tdata[8*(i+1)-1-:8] == 0);
			end
		end
		assert(fd_m_tkeep == dec_m_tkeep);
	end
end

////////////////////////////////////////////////////////////////////////////////
// check tag

always @(posedge clk) begin
	if (dec_m_tag_tvalid) begin
		assert(dec_m_tag_tdata == 0);
	end
end

////////////////////////////////////////////////////////////////////////////////
// cover

always @(posedge clk) begin
	cover(dec_m_tag_tvalid && dec_m_tag_tready);
end

endmodule
