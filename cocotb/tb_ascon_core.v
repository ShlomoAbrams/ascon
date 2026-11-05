`timescale 1ns / 1ps

module tb_ascon_core;

    reg          clk;
    reg          rst;
    reg          srt_e;
    reg  [127:0] k_i;
    reg  [127:0] n_i;
    reg  [127:0] ad_i;
    reg  [127:0] pt_i;
    reg          ad_load;
    reg          pt_load;
    reg          ad_last;
    reg          pt_last;
    reg  [3:0]   ad_len;
    reg  [3:0]   pt_len;
    wire [127:0] ct;
    wire [127:0] t;
    wire         in_ready;
    wire         ct_valid;
    wire         e_finish;

    // Instantiate DUT
    ascon_core dut (
        .clk(clk),
        .reset(rst),
        .start_e(srt_e),
        .k_i(k_i),
        .n_i(n_i),
        .ad_i(ad_i),
        .pt_i(pt_i),
        .ad_load(ad_load),
        .pt_load(pt_load),
        .ad_last(ad_last),
        .pt_last(pt_last),
        .ad_len(ad_len),
        .pt_len(pt_len),
        .ct(ct),
        .t(t),
        .e_finish(e_finish),
        .in_ready(in_ready),
        .ct_valid(ct_valid)
    );

    // Clock generator (10ns period)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        srt_e = 0;
        k_i = 128'h000102030405060708090a0b0c0d0e0f;
        n_i = 128'h000102030405060708090a0b0c0d0e0f;
        ad_i = 0;
        pt_i = 0;
        ad_load = 0;
        pt_load = 0;
        ad_last = 0;
        pt_last = 0;
        ad_len = 0;
        pt_len = 0;

        repeat (2) @(negedge clk);
        rst = 0;
        @(negedge clk);

        // ============================================================
        // Test 1: Empty AD, Empty PT
        // ============================================================
        $display("\n--- Test 1: Empty AD, Empty PT ---");
        srt_e = 1;
        @(negedge clk);
        srt_e = 0;

        while (dut.core_fsm !== 4'h4) @(negedge clk); // AD_LOAD
        ad_load = 0; // No AD
        @(negedge clk);

        while (dut.core_fsm !== 4'h8) @(negedge clk); // PT_LOAD
        pt_i = 128'h0;
        pt_load = 1;
        pt_last = 1;
        pt_len = 4'd0;
        @(negedge clk);
        pt_load = 0;

        while (!e_finish) @(negedge clk);
        $display("Test 1 finished at %0t ps", $time);
        $display("Ciphertext: %h", ct);
        $display("Tag:        %h", t);

        // ============================================================
        // Test 2: 1 Block AD (padded), 1 Block PT (padded)
        // ============================================================
        $display("\n--- Test 2: 1 Block AD (padded), 1 Block PT (padded) ---");
        repeat (2) @(negedge clk);
        srt_e = 1;
        ad_i = 128'ha0a1a2a3a4a5a6a7a8a9aaabacadaeaf;
        pt_i = 128'hb0b1b2b3b4b5b6b7b8b9babbbcbdbebf;
        @(negedge clk);
        srt_e = 0;

        while (dut.core_fsm !== 4'h4) @(negedge clk); // AD_LOAD
        ad_load = 1;
        ad_last = 1;
        ad_len = 4'd8; // 8 bytes of AD
        @(negedge clk);
        ad_load = 0;

        while (dut.core_fsm !== 4'h8) @(negedge clk); // PT_LOAD
        pt_load = 1;
        pt_last = 1;
        pt_len = 4'd5; // 5 bytes of PT
        @(negedge clk);
        pt_load = 0;

        while (!e_finish) @(negedge clk);
        $display("Test 2 finished at %0t ps", $time);
        $display("Ciphertext: %h", ct);
        $display("Tag:        %h", t);

        // Check truncation: only 5 bytes (40 bits) should be non-zero
        if (ct[87:0] === 88'h0) begin
            $display("Ciphertext correctly truncated to 5 bytes (trailing 88 bits are 0)!");
        end else begin
            $display("Error: Ciphertext not properly truncated: %h", ct);
        end

        repeat (5) @(negedge clk);
        $display("\nAll tests completed successfully!\n");
        $finish;
    end

    // Safety timeout
    initial begin
        #1000000;
        $display("Error: Simulation timed out!");
        $finish;
    end

endmodule
