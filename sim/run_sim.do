# ============================================================================
# ModelSim Simulation Script for Ascon-128 Tiny Tapeout (tt_um_ascon)
# Location: code/sim/run_sim.do
# Usage in ModelSim GUI console:
#   cd C:/Users/shlom/Documents/University/ascon/code/sim
#   do run_sim.do
# ============================================================================

transcript on

# Quit any currently running simulation before recompiling
quit -sim

# Automatically resolve RTL and TB directories (works from code/sim or project root)
if {[file exists "../rtl/tt_um_ascon.v"]} {
    set RTL_DIR "../rtl"
    set TB_DIR  "../tb"
} elseif {[file exists "code/rtl/tt_um_ascon.v"]} {
    set RTL_DIR "code/rtl"
    set TB_DIR  "code/tb"
} else {
    set SCRIPT_DIR [file dirname [file normalize [info script]]]
    set RTL_DIR "$SCRIPT_DIR/../rtl"
    set TB_DIR  "$SCRIPT_DIR/../tb"
}

# 1. Create and map work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# 2. Compile RTL and Testbench files
echo ">>> Compiling RTL and Testbench..."
vlog -work work "$RTL_DIR/ascon_round.v"
vlog -work work "$RTL_DIR/ascon_encryption.v"
vlog -work work "$RTL_DIR/tt_um_ascon.v"
vlog -work work "$TB_DIR/tb_tt_um_ascon.v"

# 3. Launch simulator with full signal visibility (+acc)
echo ">>> Starting Simulation..."
vsim -voptargs="+acc" work.tb_tt_um_ascon

# 4. Configure Waveforms (when running in ModelSim GUI)
if {![batch_mode]} {
    # Prevent $finish from closing the ModelSim GUI window
    onfinish stop

    view wave
    delete wave *

    # -------------------------------------------------------------------------
    # Color Semantic Scheme:
    #   White:    Infrastructure (Clock & Reset)
    #   Cyan:     Input Data & Internal State
    #   Green:    Output Data (Ciphertext)
    #   Gold:     Secret Key Material
    #   Magenta:  Authentication Tag
    #   Orange:   Addresses & Round Counters
    #   Yellow:   Action / Trigger Pulses (load, write)
    #   Sky Blue: Status "Ready" Handshakes
    #   Lime:     Status "Valid" / "Finished" Flags
    #   Coral:    Block Qualifiers (last, data_length, ad_empty, bank)
    #   Purple:   FSM State
    # -------------------------------------------------------------------------

    # Group 1: Top-Level Tiny Tapeout Pins
    add wave -noupdate -divider "1. Tiny Tapeout Pins (tt_um_ascon)"
    add wave -noupdate -color White       -radix binary       /tb_tt_um_ascon/clk
    add wave -noupdate -color White       -radix binary       /tb_tt_um_ascon/rst_n
    add wave -noupdate -color Cyan        -radix hexadecimal  /tb_tt_um_ascon/ui_in
    add wave -noupdate -color Green       -radix hexadecimal  /tb_tt_um_ascon/uo_out
    add wave -noupdate -color Coral       -radix hexadecimal  /tb_tt_um_ascon/uio_in

    # Group 2: Wrapper Control & Shared Buffer
    add wave -noupdate -divider "2. Wrapper Control & Shared Buffer"
    add wave -noupdate -color Orange      -radix hexadecimal  /tb_tt_um_ascon/dut/byte_addr
    add wave -noupdate -color Coral       -radix binary       /tb_tt_um_ascon/dut/bank
    add wave -noupdate -color Coral       -radix binary       /tb_tt_um_ascon/dut/read_tag
    add wave -noupdate -color Yellow      -radix binary       /tb_tt_um_ascon/dut/write_raw
    add wave -noupdate -color Yellow      -radix binary       /tb_tt_um_ascon/dut/write_pulse
    add wave -noupdate -color Cyan        -radix hexadecimal  /tb_tt_um_ascon/dut/buffer
    add wave -noupdate -color Lime        -radix binary       /tb_tt_um_ascon/dut/ct_ready
    add wave -noupdate -color Lime        -radix binary       /tb_tt_um_ascon/dut/finish_reg

    # Group 3: Ascon Core FSM & Handshake Signals
    add wave -noupdate -divider "3. Ascon Encryption Core (u_encryption)"
    add wave -noupdate -color Purple      -radix unsigned     /tb_tt_um_ascon/dut/u_encryption/fsm
    add wave -noupdate -color Orange      -radix unsigned     /tb_tt_um_ascon/dut/u_encryption/i
    add wave -noupdate -color Orange      -radix hexadecimal  /tb_tt_um_ascon/dut/u_encryption/round_c
    add wave -noupdate -color Yellow      -radix binary       /tb_tt_um_ascon/dut/u_encryption/load
    add wave -noupdate -color Coral       -radix binary       /tb_tt_um_ascon/dut/u_encryption/last
    add wave -noupdate -color Coral       -radix unsigned     /tb_tt_um_ascon/dut/u_encryption/data_length
    add wave -noupdate -color Coral       -radix binary       /tb_tt_um_ascon/dut/u_encryption/ad_empty
    add wave -noupdate -color "Sky Blue"  -radix binary       /tb_tt_um_ascon/dut/u_encryption/ready_for_nonce
    add wave -noupdate -color "Sky Blue"  -radix binary       /tb_tt_um_ascon/dut/u_encryption/ready_for_key
    add wave -noupdate -color "Sky Blue"  -radix binary       /tb_tt_um_ascon/dut/u_encryption/ready_for_ad
    add wave -noupdate -color "Sky Blue"  -radix binary       /tb_tt_um_ascon/dut/u_encryption/ready_for_pt
    add wave -noupdate -color Lime        -radix binary       /tb_tt_um_ascon/dut/u_encryption/ct_valid
    add wave -noupdate -color Lime        -radix binary       /tb_tt_um_ascon/dut/u_encryption/finish

    # Group 4: 320-bit State, Key, Ciphertext, and Tag
    add wave -noupdate -divider "4. Cryptographic State & Outputs"
    add wave -noupdate -color Gold        -radix hexadecimal  /tb_tt_um_ascon/dut/u_encryption/k
    add wave -noupdate -color Cyan        -radix hexadecimal  /tb_tt_um_ascon/dut/u_encryption/state
    add wave -noupdate -color Green       -radix hexadecimal  /tb_tt_um_ascon/dut/u_encryption/ct
    add wave -noupdate -color Magenta     -radix hexadecimal  /tb_tt_um_ascon/dut/u_encryption/t

    configure wave -namecolwidth 260
    configure wave -valuecolwidth 220
}

# 5. Run simulation to completion
run -all

if {![batch_mode]} {
    wave zoom full
}

