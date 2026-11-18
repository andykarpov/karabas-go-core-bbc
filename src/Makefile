# BBC Micro core: the Ф0 fit checks (the board flow comes in Ф1).
#
#   make measure-master   XST of bbc_micro_core as the Master 128 (AlanD 65C02)
#   make measure-beeb     XST of bbc_micro_core as the Model B (T65 6502)
#   make measure-report   LUTs, FFs, block RAMs and the XST clock estimate of both
#   make measure-hier     Master with -keep_hierarchy Yes + netgen, LUTs per module (tools/lut_breakdown.py)
#   make clean            the intermediate files
#
# Both: every option on (SPI SD, SID, Music 5000 + filter, mixer / resampler, speech,
# CoPro 65C02, VideoNuLA, VGA scan doubler, serial / tape) except HDMI and the ICE debugger.
# The top is measured with -iobuf NO: the logic it keeps is what drives the core ports.

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c

XIL = source $(ISE_SETTINGS) > /dev/null;

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

MEASURES = master beeb hier
PRJ = measure/bbc_core.prj

.PHONY: clean measure-hier measure-report $(MEASURES:%=measure-%)

define measure
bbc_$(1).ngc: measure/bbc_$(1).xst $(PRJ) $$(call prj_src,$(PRJ))
	mkdir -p xst_$(1)/projnav.tmp
	$(XIL) xst -intstyle ise -ifn measure/bbc_$(1).xst -ofn bbc_$(1).syr > measure/xst_$(1).log
measure-$(1): bbc_$(1).ngc
endef
$(foreach m,$(MEASURES),$(eval $(call measure,$(m))))

measure-hier: bbc_hier.ngc
	mkdir -p xst_hier/nl
	$(XIL) netgen -w -ofmt verilog -sim bbc_hier.ngc xst_hier/nl/hier.v > xst_hier/nl/netgen.log
	python3 -I tools/lut_breakdown.py xst_hier/nl/hier.v

measure-report:
	@for m in $(MEASURES); do f=bbc_$$m.syr; [ -f $$f ] || continue; echo "== $$m"; \
	sed -n '/Device utilization summary/,/Partition Resource Summary/p' $$f \
		| grep -E "Number of (Slice Registers|Slice LUTs|used as Memory|Block RAM/FIFO|DSP48)"; \
	grep -E "Minimum period" $$f | sort -u | head -3; done

clean:
	rm -rf $(MEASURES:%=xst_%) _xmsgs xlnx_auto_0_xdb iseconfig
	rm -f $(foreach m,$(MEASURES),$(addprefix bbc_$(m),.ngc .ngr .syr .lso _xst.xrpt)) measure/xst_*.log
