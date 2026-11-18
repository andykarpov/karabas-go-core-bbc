# BBC Micro core: the ISE 14.7 flow of the boards (as core-cpc) and the Ф0 fit checks.
#
#   make minig            a board: <board>-xst (.ngc), <board>-impl (.bin), <board>-core (.kg)
#   make minig-report     LUTs, slices, block RAMs and the timing result of the last build
#   make roms             the ROM images of the .kg (tools/bbc_roms.sh -> roms/kg/, in git)
#   make measure-master   Ф0: XST of bbc_micro_core as the Master 128 (AlanD 65C02)
#   make measure-beeb     Ф0: XST of bbc_micro_core as the Model B (T65 6502)
#   make measure-hier     Ф0: Master with -keep_hierarchy Yes + netgen, LUTs per module (tools/lut_breakdown.py)
#   make measure-report   LUTs, FFs, block RAMs and the XST clock estimate of the measures
#   make clean            the intermediate files (not the .bin / .kg files, they are in git)
#
# Ф0 measures: every option on (SPI SD, SID, Music 5000 + filter, mixer / resampler, speech,
# CoPro 65C02, VideoNuLA, VGA scan doubler, serial / tape) except HDMI and the ICE debugger,
# with -iobuf NO: the logic kept is what drives the core ports.
# Boards: karabas_<board>.prj (tools/board_modules.prj + rtl/sv2v (tools/sv2v.sh) + measure/bbc_core.prj + rtl/karabas), .xst,
# .ut, .ucf; the configuration of the core is in rtl/karabas/bbc_kg_core.vhd.

ISE_SETTINGS ?= /opt/Xilinx/14.7/ISE_DS/settings64.sh

SHELL = /bin/bash
.SHELLFLAGS = -e -o pipefail -c

XIL = source $(ISE_SETTINGS) > /dev/null;

prj_src = $(shell sed -n 's/^[a-z]* work "\(.*\)"/\1/p' $(1) 2>/dev/null)

PART = xc6slx25-ftg256-2
BOARDS = go mini minig

# all boards in one file: a board build puts its bitstream in (make_core --boards)
KG = bbc.kg
JSON = core.json
ROMS = roms/kg/beeb.rom roms/kg/master.rom roms/kg/fs.rom

# map / par options (cost table 2 by default, the rule of all the cores)
MAP_T_go ?= 2
MAP_T_mini ?= 2
MAP_T_minig ?= 2
MAP = -logic_opt off -ol high -xe n -xt 3 -register_duplication off -r 4 -global_opt off -mt 2 -detail -ir off -pr b -lc auto -power off
PAR = -ol high -xe c -mt 4

# included or read by the sources, not in the prj
INCLUDES = $(wildcard ../modules/rtl/mcu/*.vh) rtl/beeb/Tube/gen_flag_v3.v

.NOTPARALLEL:

define board
SRC_$(1) := $$(call prj_src,karabas_$(1).prj)

karabas_$(1).ngc: karabas_$(1).prj karabas_$(1).xst $$(SRC_$(1)) $(INCLUDES)
	mkdir -p xst/projnav.tmp
	$(XIL) xst -intstyle ise -ifn karabas_$(1).xst -ofn karabas_$(1).syr

karabas_$(1).bin: karabas_$(1).ngc karabas_$(1).ucf karabas_$(1).ut
	$(XIL) ngdbuild -intstyle ise -dd _ngo -nt timestamp -uc karabas_$(1).ucf -p $(PART) karabas_$(1).ngc karabas_$(1).ngd
	$(XIL) map -intstyle ise -p $(PART) -w $(MAP) -t $(MAP_T_$(1)) -o karabas_$(1)_map.ncd karabas_$(1).ngd karabas_$(1).pcf
	$(XIL) par -w -intstyle ise $(PAR) karabas_$(1)_map.ncd karabas_$(1).ncd karabas_$(1).pcf
	$(XIL) trce -intstyle ise -v 3 -s 2 -n 3 -fastpaths -xml karabas_$(1).twx karabas_$(1).ncd -o karabas_$(1).twr karabas_$(1).pcf -ucf karabas_$(1).ucf
	$(XIL) bitgen -intstyle ise -f karabas_$(1).ut karabas_$(1).ncd

kg_$(1).stamp: karabas_$(1).bin $(JSON) $(ROMS)
	python3 tools/check_osd.py $(JSON)
	python3 make_core.py $(JSON) $(KG) --boards $(1)
	touch $$@

$(1): kg_$(1).stamp
$(1)-xst: karabas_$(1).ngc
$(1)-impl: karabas_$(1).bin
$(1)-core: kg_$(1).stamp
$(1)-report:
	@grep -E "Number of (Slice LUTs|occupied Slices|RAMB16BWERs|RAMB8BWERs|DSP48A1s):" karabas_$(1)_map.mrp
	@grep -E "constraints? (was|were) met|constraints? not met|Timing Score" karabas_$(1).par | sort -u
endef

$(foreach b,$(BOARDS),$(eval $(call board,$(b))))

roms $(ROMS): tools/bbc_roms.sh
	tools/bbc_roms.sh

MEASURES = master beeb hier
PRJ = measure/bbc_core.prj

.PHONY: all roms clean measure-hier measure-report $(BOARDS) $(BOARDS:=-xst) $(BOARDS:=-impl) $(BOARDS:=-core) $(BOARDS:=-report) $(MEASURES:%=measure-%)

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
	rm -rf xst _ngo xlnx_auto_0_xdb _xmsgs
	rm -f $(foreach b,$(BOARDS),$(addprefix karabas_$(b),.ngc .ngr .syr .lso _xst.xrpt .ngd .pcf _map.ncd _map.map _map.mrp _map.ngm .ncd .par .pad .twr .twx .bgn .bit .drc .ptwx .unroutes .xpi _pad.csv _pad.txt _summary.xml _usage.xml _bitgen.xwbt _ngdbuild.xrpt) kg_$(b).stamp)
	rm -rf $(MEASURES:%=xst_%) _xmsgs xlnx_auto_0_xdb iseconfig
	rm -f $(foreach m,$(MEASURES),$(addprefix bbc_$(m),.ngc .ngr .syr .lso _xst.xrpt)) measure/xst_*.log
