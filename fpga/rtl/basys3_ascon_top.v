`default_nettype none

// Basys 3 FPGA Top Wrapper for Tiny Tapeout Ascon Module
// Connects Digilent Basys 3 board resources (PMODs, Clock, Reset, LEDs) to tt_um_ascon
module basys3_top (
    input  wire        clk,        // 100 MHz onboard oscillator (pin W5)
    input  wire        btnC,       // Center push-button (Active-High on Basys 3) -> Reset
    
    // PMOD JA: Dedicated Inputs (ui_in[7:0] - Write Data)
    input  wire [7:0]  ja,         // ja[3:0] = JA1..JA4, ja[7:4] = JA7..JA10
    
    // PMOD JB: Dedicated Outputs (uo_out[7:0] - Read Data)
    output wire [7:0]  jb,         // jb[3:0] = JB1..JB4, jb[7:4] = JB7..JB10
    
    // PMOD JC: IOs Input path (uio_in[7:0] - addr[5:0], write, read)
    input  wire [7:0]  jc,         // jc[3:0] = JC1..JC4, jc[7:4] = JC7..JC10
    
    // Onboard LEDs for visual status inspection
    output wire [15:0] led
);

    // -------------------------------------------------------------
    // 1. Clock Division (100 MHz -> 12.5 MHz)
    // -------------------------------------------------------------
    // Tiny Tapeout typically operates around 10-50 MHz.
    // 12.5 MHz gives ample setup/hold margins for PMOD jumper wires.
    reg [2:0] clk_div = 3'd0;
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end
    wire tt_clk = clk_div[2];

    // -------------------------------------------------------------
    // 2. Reset Inversion (Basys 3 button is Active-High, TT is Active-Low)
    // -------------------------------------------------------------
    wire rst_n = ~btnC;

    // -------------------------------------------------------------
    // 3. Exact Tiny Tapeout Module Instantiation
    // -------------------------------------------------------------
    wire [7:0] uo_out;
    tt_um_ascon u_ascon (
        .clk     (tt_clk),
        .rst_n   (rst_n),
        .ena     (1'b1),
        .ui_in   (ja),
        .uo_out  (uo_out),
        .uio_in  (jc),
        .uio_out (), // Unused in this design
        .uio_oe  ()  // Unused in this design
    );

    // Assign read data to PMOD JB
    assign jb = uo_out;

    // -------------------------------------------------------------
    // 4. Status LEDs
    // -------------------------------------------------------------
    // led[7:0]  : Reflects current read data on PMOD JB (uo_out)
    // led[13:8] : Reflects address pins (jc[5:0])
    // led[14]   : Write pulse strobe indicator (jc[6])
    // led[15]   : Read enable strobe indicator (jc[7])
    assign led[7:0]   = uo_out;
    assign led[13:8]  = jc[5:0];
    assign led[14]    = jc[6];
    assign led[15]    = jc[7];

endmodule
