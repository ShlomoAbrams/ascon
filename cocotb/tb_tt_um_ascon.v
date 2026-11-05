`timescale 1ns / 1ps

module tb_tt_um_ascon;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    // Instantiate DUT
    tt_um_ascon dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    // Clock generator (50 MHz -> 20ns period)
    always #10 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    // ========================================================================
    // Low-Level Bus Tasks (uio_in = {unused, write_raw, read_tag, bank, addr[3:0]})
    // ========================================================================
    task write_byte(input [5:0] addr, input [7:0] data);
        begin
            @(negedge clk);
            ui_in  = data;
            uio_in = {1'b0, 1'b1, addr}; // write_raw = 1
            @(negedge clk);
            @(negedge clk);              // Hold for 2-FF synchronizer
            uio_in = {1'b0, 1'b0, addr}; // De-assert write_raw
            @(negedge clk);
        end
    endtask

    task read_byte(input [5:0] addr, output [7:0] data);
        begin
            @(negedge clk);
            uio_in = {1'b0, 1'b0, addr}; // write_raw = 0, addr[5] = read_tag, addr[4] = bank
            #2;
            data = uo_out;
            @(negedge clk);
            uio_in = 8'h00;
        end
    endtask

    // ========================================================================
    // High-Level Protocol Tasks
    // ========================================================================
    task wait_status_bit(input [7:0] mask);
        reg [7:0] status;
        begin
            status = 8'h00;
            while ((status & mask) == 8'h00) begin
                read_byte(6'h10, status);
            end
        end
    endtask

    task write_buffer_128(input [127:0] blk);
        integer b;
        begin
            for (b = 0; b < 16; b = b + 1) begin
                write_byte(b[5:0], blk[127 - b*8 -: 8]);
            end
        end
    endtask

    task read_buffer_128(output [127:0] blk);
        integer b;
        reg [7:0] rbyte;
        begin
            for (b = 0; b < 16; b = b + 1) begin
                read_byte(b[5:0], rbyte);
                blk[127 - b*8 -: 8] = rbyte;
            end
        end
    endtask

    task read_tag_128(output [127:0] tag_out);
        integer b;
        reg [7:0] rbyte;
        begin
            for (b = 0; b < 16; b = b + 1) begin
                read_byte(6'h20 + b[5:0], rbyte);
                tag_out[127 - b*8 -: 8] = rbyte;
            end
        end
    endtask

    // 1. Initialize Nonce and Key
    task init_nonce_and_key(input [127:0] nonce, input [127:0] key);
        begin
            // Wait for ready_for_nonce (bit 0)
            wait_status_bit(8'h01);
            write_buffer_128(nonce);
            write_byte(6'h10, 8'h01); // load = 1

            // Wait for ready_for_key (bit 1)
            wait_status_bit(8'h02);
            write_buffer_128(key);
            write_byte(6'h10, 8'h01); // load = 1 (starts 12-round init permutation)
        end
    endtask

    // 2a. Skip AD phase (ad_empty = 1)
    task skip_ad_phase;
        begin
            wait_status_bit(8'h04);   // Wait for ready_for_ad (bit 2)
            write_byte(6'h10, 8'h40); // ad_empty = 1 (bit 6)
        end
    endtask

    // 2b. Send one block of AD
    task send_ad_block(input [127:0] ad_blk, input [3:0] len, input is_last);
        begin
            wait_status_bit(8'h04); // Wait for ready_for_ad (bit 2)
            write_buffer_128(ad_blk);
            // Control byte: {1'b0, ad_empty(0), len[3:0], is_last, load(1)}
            write_byte(6'h10, {2'b00, len, is_last, 1'b1});
        end
    endtask

    // 3. Send one block of PT and read back resulting CT block
    task send_pt_and_read_ct(
        input  [127:0] pt_blk,
        input  [3:0]   len,
        input          is_last,
        output [127:0] ct_blk
    );
        begin
            wait_status_bit(8'h08); // Wait for ready_for_pt (bit 3)
            write_buffer_128(pt_blk);
            // Control byte: {1'b0, ad_empty(0), len[3:0], is_last, load(1)}
            write_byte(6'h10, {2'b00, len, is_last, 1'b1});

            // Wait for ct_ready (bit 4)
            wait_status_bit(8'h10);
            read_buffer_128(ct_blk);
        end
    endtask

    // 4. Wait for finish and read Tag
    task finish_and_read_tag(output [127:0] tag_out);
        begin
            wait_status_bit(8'h20); // Wait for finish_reg (bit 5)
            read_tag_128(tag_out);
        end
    endtask

    // 5. Verification helper
    task check_result(
        input [8*60-1:0] label,
        input [127:0]    actual,
        input [127:0]    expected
    );
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s = %032h", label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s", label);
                $display("         Actual  : %032h", actual);
                $display("         Expected: %032h", expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========================================================================
    // Main Test Suite
    // ========================================================================
    reg [127:0] ct0, ct1, ct2, tag;

    initial begin
        clk    = 0;
        rst_n  = 0;
        ena    = 1;
        ui_in  = 8'h00;
        uio_in = 8'h00;

        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (4) @(negedge clk);

        $display("==================================================================");
        $display("   ASCON-128 TinyTapeout Comprehensive Verification Suite");
        $display("==================================================================");

        // --------------------------------------------------------------------
        // TEST 1: Classic 1-Block AD (8B) + 1-Block PT (5B)
        // --------------------------------------------------------------------
        $display("\n--- Test 1: 1-Block AD (8B) + 1-Block PT (5B) ---");
        init_nonce_and_key(128'h000102030405060708090a0b0c0d0e0f,
                           128'h000102030405060708090a0b0c0d0e0f);
        send_ad_block(128'ha0a1a2a3a4a5a6a7a8a9aaabacadaeaf, 4'd8, 1'b1);
        send_pt_and_read_ct(128'hb0b1b2b3b4b5b6b7b8b9babbbcbdbebf, 4'd5, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 1 CT[0]", ct0, 128'h91f5f635690000000000000000000000);
        check_result("Test 1 TAG  ", tag, 128'h09bc056f68406a5a3ef6518eb967e09c);

        // --------------------------------------------------------------------
        // TEST 2: Empty AD (ad_empty=1) + 1-Block PT (10B)
        // --------------------------------------------------------------------
        $display("\n--- Test 2: Empty AD (ad_empty=1) + 1-Block PT (10B) ---");
        init_nonce_and_key(128'h101112131415161718191a1b1c1d1e1f,
                           128'h000102030405060708090a0b0c0d0e0f);
        skip_ad_phase();
        send_pt_and_read_ct(128'h0102030405060708090a0b0c0d0e0f10, 4'd10, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 2 CT[0]", ct0, 128'h42d9bd80dba205d67bd6000000000000);
        check_result("Test 2 TAG  ", tag, 128'h62ea5efbb79a0497e92e281ff81c666c);

        // --------------------------------------------------------------------
        // TEST 3: Empty AD (ad_empty=1) + Empty PT (0B)
        // --------------------------------------------------------------------
        $display("\n--- Test 3: Empty AD (ad_empty=1) + Empty PT (0B) ---");
        init_nonce_and_key(128'h0123456789abcdef0123456789abcdef,
                           128'hfedcba9876543210fedcba9876543210);
        skip_ad_phase();
        send_pt_and_read_ct(128'hffffffffffffffffffffffffffffffff, 4'd0, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 3 CT[0]", ct0, 128'h00000000000000000000000000000000);
        check_result("Test 3 TAG  ", tag, 128'he8608b81843deaee18e666cac5bd3586);

        // --------------------------------------------------------------------
        // TEST 4: 1-Block AD (15B) + Empty PT (0B - MAC-only mode)
        // --------------------------------------------------------------------
        $display("\n--- Test 4: 1-Block AD (15B) + Empty PT (0B - MAC only) ---");
        init_nonce_and_key(128'h112233445566778899aabbccddeeff00,
                           128'hdeadbeefcafebabe0123456789abcdef);
        send_ad_block(128'h123456789abcdef0123456789abcdef0, 4'd15, 1'b1);
        send_pt_and_read_ct(128'ha5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5, 4'd0, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 4 CT[0]", ct0, 128'h00000000000000000000000000000000);
        check_result("Test 4 TAG  ", tag, 128'h9c532937fbdbe1b5cb4102599cc253f8);

        // --------------------------------------------------------------------
        // TEST 5: Multi-Block AD (2 blocks: 16B + 7B) + 1-Block PT (9B)
        // --------------------------------------------------------------------
        $display("\n--- Test 5: 2-Block AD (16B + 7B) + 1-Block PT (9B) ---");
        init_nonce_and_key(128'h000102030405060708090a0b0c0d0e0f,
                           128'h000102030405060708090a0b0c0d0e0f);
        send_ad_block(128'ha0a1a2a3a4a5a6a7a8a9aaabacadaeaf, 4'd0, 1'b0); // full 16B block (last=0)
        send_ad_block(128'hb0b1b2b3b4b5b6b7b8b9babbbcbdbebf, 4'd7, 1'b1); // partial 7B block (last=1)
        send_pt_and_read_ct(128'hc0c1c2c3c4c5c6c7c8c9cacbcccdcecf, 4'd9, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 5 CT[0]", ct0, 128'hd3f778e20424fae34900000000000000);
        check_result("Test 5 TAG  ", tag, 128'ha51c03a61a87311504c21bd51ae56fb3);

        // --------------------------------------------------------------------
        // TEST 6: 1-Block AD (4B) + Multi-Block PT (2 blocks: 16B + 11B)
        // --------------------------------------------------------------------
        $display("\n--- Test 6: 1-Block AD (4B) + 2-Block PT (16B + 11B) ---");
        init_nonce_and_key(128'h1234567890abcdef1234567890abcdef,
                           128'h5555555555555555aaaaaaaaaaaaaaaa);
        send_ad_block(128'hdeadbeef000000000000000000000000, 4'd4, 1'b1);
        send_pt_and_read_ct(128'h00112233445566778899aabbccddeeff, 4'd0,  1'b0, ct0); // full 16B block (last=0)
        send_pt_and_read_ct(128'hffeeddccbbaa99887766554433221100, 4'd11, 1'b1, ct1); // partial 11B block (last=1)
        finish_and_read_tag(tag);
        check_result("Test 6 CT[0]", ct0, 128'h276a0820947f0e7a4d86a3e04ddb305a);
        check_result("Test 6 CT[1]", ct1, 128'h6e56eb285603ac66cd08b60000000000);
        check_result("Test 6 TAG  ", tag, 128'h52fee1e15618dbf23e3bf6515b952038);

        // --------------------------------------------------------------------
        // TEST 7: 3-Block AD (16B + 16B + 3B) + 3-Block PT (16B + 16B + 15B)
        // --------------------------------------------------------------------
        $display("\n--- Test 7: 3-Block AD (16B+16B+3B) + 3-Block PT (16B+16B+15B) ---");
        init_nonce_and_key(128'hf0e0d0c0b0a090807060504030201000,
                           128'h0f0e0d0c0b0a09080706050403020100);
        send_ad_block(128'h11111111111111112222222222222222, 4'd0, 1'b0);
        send_ad_block(128'h33333333333333334444444444444444, 4'd0, 1'b0);
        send_ad_block(128'h55555555555555556666666666666666, 4'd3, 1'b1);
        send_pt_and_read_ct(128'haaaaaaaaaaaaaaaabbbbbbbbbbbbbbbb, 4'd0,  1'b0, ct0);
        send_pt_and_read_ct(128'hccccccccccccccccdddddddddddddddd, 4'd0,  1'b0, ct1);
        send_pt_and_read_ct(128'heeeeeeeeeeeeeeeeffffffffffffffff, 4'd15, 1'b1, ct2);
        finish_and_read_tag(tag);
        check_result("Test 7 CT[0]", ct0, 128'hf14f614ac41926ea0dc0466f9554dc3a);
        check_result("Test 7 CT[1]", ct1, 128'h04a073762ebb867c3ceec954bc2bb5f9);
        check_result("Test 7 CT[2]", ct2, 128'h0a33783052fe7e99ae6cb7ef0b718300);
        check_result("Test 7 TAG  ", tag, 128'h983955fafb31d08ab6d068acb200d784);

        // --------------------------------------------------------------------
        // TEST 8: Exact 16-Byte Block Boundary (16B full + 0B padding block)
        // --------------------------------------------------------------------
        $display("\n--- Test 8: Exact 16B Block Boundary (16B + 0B pad block) ---");
        init_nonce_and_key(128'h03030303030303030404040404040404,
                           128'h01010101010101010202020202020202);
        send_ad_block(128'h0123456789abcdef0123456789abcdef, 4'd0, 1'b0);
        send_ad_block(128'h00000000000000000000000000000000, 4'd0, 1'b1);
        send_pt_and_read_ct(128'hfedcba9876543210fedcba9876543210, 4'd0, 1'b0, ct0);
        send_pt_and_read_ct(128'h00000000000000000000000000000000, 4'd0, 1'b1, ct1);
        finish_and_read_tag(tag);
        check_result("Test 8 CT[0]", ct0, 128'h116060b7f23d91fbbab2e5567aa69ec6);
        check_result("Test 8 CT[1]", ct1, 128'h00000000000000000000000000000000);
        check_result("Test 8 TAG  ", tag, 128'h17e8efad332878ba528d508b1fbc71cf);

        // --------------------------------------------------------------------
        // TEST 9: 1-Byte Boundary (len = 1 for AD and PT)
        // --------------------------------------------------------------------
        $display("\n--- Test 9: 1-Byte AD + 1-Byte PT Boundary ---");
        init_nonce_and_key(128'h76543210fedcba9876543210fedcba98,
                           128'h89abcdef0123456789abcdef01234567);
        send_ad_block(128'h42ffffffffffffffffffffffffffffff, 4'd1, 1'b1);
        send_pt_and_read_ct(128'h99ffffffffffffffffffffffffffffff, 4'd1, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 9 CT[0]", ct0, 128'h22000000000000000000000000000000);
        check_result("Test 9 TAG  ", tag, 128'h01bae71bc7791e2df7633598eb639bfc);

        // --------------------------------------------------------------------
        // TEST 10: 14-Byte AD + 14-Byte PT
        // --------------------------------------------------------------------
        $display("\n--- Test 10: 14-Byte AD + 14-Byte PT ---");
        init_nonce_and_key(128'h9876543210fedcba9876543210fedcba,
                           128'habcdef0123456789abcdef0123456789);
        send_ad_block(128'h0102030405060708090a0b0c0d0effff, 4'd14, 1'b1);
        send_pt_and_read_ct(128'hf1f2f3f4f5f6f7f8f9fafbfcfdfeffff, 4'd14, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 10 CT[0]", ct0, 128'h3f85590eb01e2c4c36c8166eba460000);
        check_result("Test 10 TAG  ", tag, 128'h27e4d580e441046aeb2d5288ec1a663c);

        // --------------------------------------------------------------------
        // TEST 11: Mid-Operation Reset Recovery Test
        // --------------------------------------------------------------------
        $display("\n--- Test 11: Mid-Operation Hardware Reset & Recovery ---");
        init_nonce_and_key(128'hdeadbeefdeadbeefdeadbeefdeadbeef,
                           128'hcafebabecafebabecafebabecafebabe);
        // Assert reset in the middle of AD waiting state
        wait_status_bit(8'h04);
        @(negedge clk);
        rst_n = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);
        // Re-run Test 1 after reset to prove clean recovery
        init_nonce_and_key(128'h000102030405060708090a0b0c0d0e0f,
                           128'h000102030405060708090a0b0c0d0e0f);
        send_ad_block(128'ha0a1a2a3a4a5a6a7a8a9aaabacadaeaf, 4'd8, 1'b1);
        send_pt_and_read_ct(128'hb0b1b2b3b4b5b6b7b8b9babbbcbdbebf, 4'd5, 1'b1, ct0);
        finish_and_read_tag(tag);
        check_result("Test 11 CT[0]", ct0, 128'h91f5f635690000000000000000000000);
        check_result("Test 11 TAG  ", tag, 128'h09bc056f68406a5a3ef6518eb967e09c);

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("   TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("==================================================================");
        if (fail_count == 0) begin
            $display(">>> ALL TESTS PASSED SUCCESSFULLY! <<<");
        end else begin
            $display(">>> SOME TESTS FAILED! <<<");
        end
        $finish;
    end

    // Safety timeout
    initial begin
        #5000000;
        $display("Error: Simulation Timed Out!");
        $finish;
    end

endmodule
