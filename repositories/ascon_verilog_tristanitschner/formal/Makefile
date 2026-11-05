SBY_FILES := $(wildcard *.sby)

COVER_TARGETS := $(SBY_FILES:.sby=_cover.ran)
BMC_TARGETS   := $(SBY_FILES:.sby=_bmc.ran)

all: cover bmc

.PHONY: cover bmc

cover: $(COVER_TARGETS)
bmc:   $(BMC_TARGETS)

%_cover.ran: %.sby
	sby -f $< cover
	touch $@

%_bmc.ran: %.sby
	sby -f $< bmc
	touch $@

clean:
	$(RM) -r $(COVER_TARGETS)
	$(RM) -r $(BMC_TARGETS)
