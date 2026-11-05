
## Constraints file for Basys 3 FPGA Board (Digilent XC7A35T-1CPG236C)
## Project: Ascon Hardware Verification on Tiny Tapeout Wrapper

## --------------------------------------------------------------------
## Clock Signal (100 MHz onboard oscillator)
## --------------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]							
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## --------------------------------------------------------------------
## Center Push Button (btnC) -> Reset (Active-High on Basys 3)
## --------------------------------------------------------------------
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]; 

## --------------------------------------------------------------------
## PMOD JA: ui_in[7:0] (Write Data Bus)
## Note: Basys 3 PMOD headers have pins:
##   Top Row:    Pin 1,  Pin 2,  Pin 3,  Pin 4
##   Bottom Row: Pin 7,  Pin 8,  Pin 9,  Pin 10
## --------------------------------------------------------------------
set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports {ja[0]}];	# JA1				
set_property -dict {PACKAGE_PIN L2 IOSTANDARD LVCMOS33} [get_ports {ja[1]}];	# JA2					
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {ja[2]}];	# JA3					
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {ja[3]}];	# JA4

set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33} [get_ports {ja[4]}];	# JA7					
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports {ja[5]}];	# JA8					
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {ja[6]}];	# JA9					
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports {ja[7]}]; 	# JA10					

## --------------------------------------------------------------------
## PMOD JB: uo_out[7:0] (Read Data Bus)
## --------------------------------------------------------------------
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports {jb[0]}];   # JB1					
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports {jb[1]}];	# JB2					
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS33} [get_ports {jb[2]}];	# JB3					
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {jb[3]}];	# JB4

set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {jb[4]}];	# JB7					
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {jb[5]}];	# JB8					
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports {jb[6]}];	# JB9					
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {jb[7]}];	# JB10

## --------------------------------------------------------------------
## PMOD JC: uio_in[7:0] (addr[5:0], write, read)
## --------------------------------------------------------------------
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports {jc[0]}];	# JC1					
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {jc[1]}];	# JC2					
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {jc[2]}];	# JC3
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {jc[3]}];	# JC4

set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports {jc[4]}];	# JC7					
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports {jc[5]}];	# JC8					
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {jc[6]}];	# JC9					
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {jc[7]}];	# JC10

## --------------------------------------------------------------------
## Onboard LEDs
## --------------------------------------------------------------------
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}];	# LED0
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}];	# LED1
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}];	# LED2
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}];	# LED3
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}];	# LED4
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {led[5]}];	# LED5
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[6]}];	# LED6
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[7]}];	# LED7
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {led[8]}];	# LED8
set_property -dict {PACKAGE_PIN V3 IOSTANDARD LVCMOS33} [get_ports {led[9]}];	# LED9
set_property -dict {PACKAGE_PIN W3 IOSTANDARD LVCMOS33} [get_ports {led[10]}];	# LED10
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports {led[11]}];	# LED11
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {led[12]}];	# LED12					
set_property -dict {PACKAGE_PIN N3 IOSTANDARD LVCMOS33} [get_ports {led[13]}];	# LED13
set_property -dict {PACKAGE_PIN P1 IOSTANDARD LVCMOS33} [get_ports {led[14]}];	# LED14
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33} [get_ports {led[15]}];	# LED15

## --------------------------------------------------------------------
## Configuration Bank Voltage & Bitstream Settings
## --------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
