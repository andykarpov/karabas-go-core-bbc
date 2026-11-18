#!/bin/bash
# The ROM images of the .kg (core.json "roms"): 16 sideways ROM slots of 16 KB = 256 KB each, the
# order of BeebFpga roms/make_rom_image_tangnano.sh (the external memory map of bbc_micro_core:
# 0x00000-0x3FFFF = slots 0-3, MOS, -, -, the 6502 Tube ROM, slots 8-F). One image per
# { filing system, model } = a 512 KB bank of the SRAM (rtl/karabas/bbc_mem.v):
#   roms/kg/beeb_mmfs.rom    -> 0x000000     roms/kg/master_mmfs.rom  -> 0x080000
#   roms/kg/beeb_mmfs2.rom   -> 0x100000     roms/kg/master_mmfs2.rom -> 0x180000
# Model B: slot 8 SWMMFS (sideways RAM MMFS: the core maps the upper part of slot 8 to RAM),
#   E RAM Master v6 (the sideways RAM manager), F BASIC 2.
# Master 128: 8 DFS (for the SRAM utilities), 9 MAMMFS, A ViewSheet, B Edit, C BASIC 4, D ADFS,
#   E View, F Terminal.
# usage: tools/bbc_roms.sh (from src/)
set -e
cd "$(dirname "$0")/../roms"
mkdir -p kg
B=generic/blank.rom
for M in MMFS MMFS2; do
	m=$(echo $M | tr A-Z a-z)
	cat $B $B $B $B bbcb/os12.rom $B $B tube/tube120.rom \
	    bbcb/$M/M/SWMMFS.rom $B $B $B $B $B bbcb/ram_master_v6.rom bbcb/basic2.rom > kg/beeb_$m.rom
	cat $B $B $B $B m128/mos.rom $B $B tube/tube120.rom \
	    m128/dfs.rom m128/$M/M/MAMMFS.rom m128/viewsht.rom m128/edit.rom \
	    m128/basic4.rom m128/adfs.rom m128/view.rom m128/terminal.rom > kg/master_$m.rom
done
for f in kg/*.rom; do
	s=$(stat -c %s $f)
	[ $s -eq 262144 ] || { echo "$f: $s bytes, not 262144"; exit 1; }
done
ls -l kg
