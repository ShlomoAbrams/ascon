#!/bin/env python

from math import ceil
import argparse as ap
import sys

# Description:
# * performance calculation tool for this ascon cipher implementation
# Note:
# * this has not been compared to hardware performance, so there may be small
# errors

# length assumed to be in bytes, returns beats
def pad_a(length):
    if length == 0: return 0
    else: return ceil((length + 1) / 16)

# length assumed to be in bytes, returns beats
def pad_p(length):
    return ceil((length + 1) / 128)

def main():
    parser = ap.ArgumentParser(prog=sys.argv[0],
                                description="performance calculation tool for this ascon cipher implementation",
                                epilog="assumes an input stream of packets of equal length")

    parser.add_argument("--ad_length",      type=int, help="Length of associated data in Bytes.",                      required=True)
    parser.add_argument("--pt_length",      type=int, help="Length of plaintext / ciphertext in Bytes.",               required=True)
    parser.add_argument("--rounds_per_clk", type=int, help="The number of rounds the core performes per clock cycle.", required=True)
    parser.add_argument("--frequency",      type=int, help="The frequency of the core in MHz.",                        required=True)

    args = parser.parse_args()

    setup_cycles = ceil(12/args.rounds_per_clk)
    data_cycles  = ceil( 8/args.rounds_per_clk)
    ad_beats     = pad_a(args.ad_length)
    p_beats      = pad_a(args.pt_length)

    total_cycles = 2*setup_cycles + data_cycles*(ad_beats + p_beats - 1) + 1

    print("Total number of cycles required per packet: %d" % total_cycles)

    T = total_cycles/args.frequency

    print("Time required: %.03f ns" % (1000.0*T))

    L = args.ad_length + args.pt_length

    L_bits = L*8

    P = L_bits/T

    print("Expected performance: %.03f Gbits/s" % (P/1000))

main()
