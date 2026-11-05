`timescale 1ns / 1ps

module tb_ascon_top;

    reg          clk;
    reg          reset;
    reg          start;
    reg  [127:0] k;
    reg  [127:0] n;
    reg  [127:0] ad;
    reg  [127:0] pt;
    reg          ad_last;
    reg          pt_last;
    reg  [3:0]   ad_len;
    reg  [3:0]   pt_len;
    wire [127:0] ct;
    wire [127:0] t;
    wire         finish;
    wire         ct_valid;
    wire         in_ready;

    // Instantiate ascon_top
    ascon_top dut (
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .k       (k),
        .n       (n),
        .ad      (ad),
        .pt      (pt),
        .ad_last (ad_last),
        .pt_last (pt_last),
        .ad_len  (ad_len),
        .pt_len  (pt_len),
        .ct      (ct),
        .t       (t),
        .finish  (finish),
        .ct_valid(ct_valid),
        .in_ready(in_ready)
    );

    // Clock generator (10ns period)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        k = 128'h000102030405060708090a0b0c0d0e0f;
        n = 128'h000102030405060708090a0b0c0d0e0f;
        ad = 128'ha0a1a2a3a4a5a6a7a8a9aaabacadaeaf;
        pt = 128'hb0b1b2b3b4b5b6b7b8b9babbbcbdbebf;
        ad_last = 1;
        pt_last = 1;
        ad_len = 4'd8;
        pt_len = 4'd5;

        repeat (2) @(negedge clk);
        reset = 0;
        @(negedge clk);

        $display("\n--- Testing ascon_top sequencer ---");
        start = 1;
        @(negedge clk);
        start = 0;

        // Wait until finish
        while (!finish) @(negedge clk);
        $display("ascon_top finished at %0t ps", $time);
        $display("Ciphertext: %h", ct);
        $display("Tag:        %h", t);

        if (ct[87:0] === 88'h0 && t === 128'h09bc056f68406a5a3ef6518eb967e09c) begin
            $display(">>> ascon_top TEST PASSED! Output matches expected test vector!");
        end else begin
            $display(">>> ascon_top output mismatch!");
        end

        repeat (5) @(negedge clk);
        $finish;
    end

    // Safety timeout
    initial begin
        #1000000;
        $display("Error: Simulation timed out!");
        $finish;
    end

endmodule
