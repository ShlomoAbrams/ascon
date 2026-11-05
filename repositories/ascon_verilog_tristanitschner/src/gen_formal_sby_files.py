#!/bin/env python3

import sys

template = """
[tasks]
bmc
cover

[options]
bmc: mode bmc
cover: mode cover
bmc: depth 10
cover: depth 18

[engines]
bmc: smtbmc
cover: smtbmc

[script]
read_verilog ascon_round.v
read_verilog ascon_p.v
read_verilog ascon_pad.v
read_verilog ascon_regslice.v
read_verilog ascon_skidbuffer.v
read_verilog ascon_isolator.v
read_verilog ascon_aead128_core.v
read_verilog -formal ascon_aead128.v

chparam -set rounds_per_clk 12 ascon_aead128
chparam -set l2_bw 3 ascon_aead128
chparam -set formal_enc_decn %d ascon_aead128
chparam -set formal_testcase %d ascon_aead128
chparam -set formal_testcases_enabled 1 ascon_aead128

prep -top ascon_aead128

[files]
../formal_rtl_gen/ascon_aead128_formal_testcases.v
../rtl/ascon_round.v
../rtl/ascon_p.v
../rtl/ascon_pad.v
../rtl/ascon_regslice.v
../rtl/ascon_skidbuffer.v
../rtl/ascon_isolator.v
../rtl/ascon_aead128_core.v
../rtl/ascon_aead128.v
"""

def main():
    n_testcases = 1089
    for i in range(n_testcases):
        output_dir = sys.argv[1]
        output_filename = "ascon_aead128_testcase%04d_enc.sby" % i
        with open(output_dir + "/" + output_filename, "w") as f:
            f.write(template % (1, i))
        output_filename = "ascon_aead128_testcase%04d_dec.sby" % i
        with open(output_dir + "/" + output_filename, "w") as f:
            f.write(template % (0, i))

main()
