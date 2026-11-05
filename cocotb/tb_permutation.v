`timescale 1ns / 1ps

module tb_permutation;

    reg clk;
    reg reset;
    reg start;
    reg rnd;
    reg [319:0] state_i;
    wire finish;
    wire [319:0] state_o;

    // Instantiate DUT
    permutation dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .rnd(rnd),
        .state_i(state_i),
        .finish(finish),
        .state_o(state_o)
    );

    // Clock generator (10ns period)
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        rnd = 0;
        state_i = 0;

        #20;
        reset = 0;
        #10;

        // -------------------------------------------------------------
        // Test 1: 12 rounds (rnd = 0)
        // -------------------------------------------------------------
        $display("\n--- Test 1: 12-round permutation ---");
        state_i = {5{64'hdeadbabecafef00f}};
        rnd = 1'b0;
        start = 1'b1;
        #10;
        start = 1'b0;

        // Wait until finish is asserted
        @(posedge finish);
        #1;
        $display("Expected: ce4b4643b452d985977944f300f18d208f02c4d5c2522ff54ae0c522cf83c29bc427bd62cc8c5fb2");
        $display("Actual:   %h", state_o);
        if (state_o === 320'hce4b4643b452d985977944f300f18d208f02c4d5c2522ff54ae0c522cf83c29bc427bd62cc8c5fb2) begin
            $display(">>> TEST 1 PASSED!");
        end else begin
            $display(">>> TEST 1 FAILED!");
        end

        #20;

        // -------------------------------------------------------------
        // Test 2: 8 rounds (rnd = 1)
        // -------------------------------------------------------------
        $display("\n--- Test 2: 8-round permutation ---");
        state_i = {5{64'hdeadbabecafef00f}};
        rnd = 1'b1;
        start = 1'b1;
        #10;
        start = 1'b0;

        @(posedge finish);
        #1;
        $display("Expected: 96ddbdd681e6b8f205ba5a96377e14d6552ffd6538e7588ed6fd8f16ded06e02ec7fea26515d5deb");
        $display("Actual:   %h", state_o);
        if (state_o === 320'h96ddbdd681e6b8f205ba5a96377e14d6552ffd6538e7588ed6fd8f16ded06e02ec7fea26515d5deb) begin
            $display(">>> TEST 2 PASSED!");
        end else begin
            $display(">>> TEST 2 FAILED!");
        end

        #50;
        $display("\nSimulation finished.\n");
        $finish;
    end

endmodule
