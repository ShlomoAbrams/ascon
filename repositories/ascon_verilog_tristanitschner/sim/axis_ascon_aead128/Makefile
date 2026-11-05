SRC += axis_ascon_aead128_tb.v

SRC += ../../rtl/ascon_aead128_core.v
SRC += ../../rtl/ascon_aead128.v
SRC += ../../rtl/ascon_isolator.v
SRC += ../../rtl/ascon_pad.v
SRC += ../../rtl/ascon_p.v
SRC += ../../rtl/ascon_regslice.v
SRC += ../../rtl/ascon_round.v
SRC += ../../rtl/ascon_skidbuffer.v
SRC += ../../rtl/axis_ascon_aead128.v

# TODO: move this file somewhere more general
SRC += ../../formal_rtl/formal_fifo.v

# Icarus flags
IFLAGS += -g2005-sv
VFLAGS += -fst

# verilator flags
# TODO: fix source
VERFLAGS += -Wno-CASEINCOMPLETE
VERFLAGS += -Wno-CASEOVERLAP
VERFLAGS += -Wno-WIDTHTRUNC


.PHONY: verilator iverilog

verilator: axis_ascon_aead128_tb.vran
iverilog: axis_ascon_aead128_tb.ran

all: verilog

%.ran: %.iv
	vvp $< $(VFLAGS)
	touch $@

axis_ascon_aead128_tb.iv: $(SRC)
	iverilog $(IFLAGS) $(SRC) -o $@

%.vran: %.ver
	./obj_dir/V$(<:.ver=)
	touch $@

axis_ascon_aead128_tb.ver: $(SRC)
	verilator $(VERFLAGS) --binary -j 0 $(SRC)

.PHONY: clean
clean:
	$(RM) *.vcd
	$(RM) *.iv
	$(RM) *.ran
