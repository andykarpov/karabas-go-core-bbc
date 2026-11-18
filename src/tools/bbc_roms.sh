#!/bin/bash
# The ROM images of the .kg (core.json "roms"), the external memory map of bbc_micro_core
# (0x00000-0x3FFFF = 16 sideways ROM slots of 16 KB: slots 0-3, MOS, -, -, the 6502 Tube ROM,
# slots 8-F; BeebFpga roms/make_rom_image_tangnano.sh) and rtl/karabas/bbc_mem.v:
#   roms/kg/beeb.rom   -> 0x000000  Model B: E RAM Master v6, F BASIC 2
#   roms/kg/master.rom -> 0x080000  Master 128: A ViewSheet, B Edit, C BASIC 4, D ADFS, E View, F Terminal
#   roms/kg/fs.rom     -> 0x100000  the disc filing systems, mapped by bbc_mem onto Model B slots 3 / 8
#                                   and Master slots 8 / 9 by the OSD choice:
#                                   0 SWMMFS, 1 SWMMFS2, 2 DNFS 1.20 (8271), 3 Acorn DFS 2.26 (1770),
#                                   4 MAMMFS, 5 MAMMFS2, 6 DFS 2.24 (Master), 7 blank
# The filing system slots of beeb.rom / master.rom are blank (never read).
# usage: tools/bbc_roms.sh (from src/)
set -e
cd "$(dirname "$0")/../roms"
mkdir -p kg
rm -f kg/beeb_mmfs.rom kg/beeb_mmfs2.rom kg/master_mmfs.rom kg/master_mmfs2.rom
B=generic/blank.rom
cat $B $B $B $B bbcb/os12.rom $B $B tube/tube120.rom \
    $B $B $B $B $B $B bbcb/ram_master_v6.rom bbcb/basic2.rom > kg/beeb.rom
cat $B $B $B $B m128/mos.rom $B $B tube/tube120.rom \
    $B $B m128/viewsht.rom m128/edit.rom m128/basic4.rom m128/adfs.rom m128/view.rom m128/terminal.rom > kg/master.rom
cat bbcb/MMFS/M/SWMMFS.rom bbcb/MMFS2/M/SWMMFS.rom bbcb/DNFS-1.20.rom bbcb/Acorn-DFS-2.26.rom \
    m128/MMFS/M/MAMMFS.rom m128/MMFS2/M/MAMMFS.rom m128/dfs.rom $B > kg/fs.rom
for f in kg/beeb.rom kg/master.rom; do
	[ $(stat -c %s $f) -eq 262144 ] || { echo "$f: not 262144 bytes"; exit 1; }
done
[ $(stat -c %s kg/fs.rom) -eq 131072 ] || { echo "kg/fs.rom: not 131072 bytes"; exit 1; }
ls -l kg
