#!/bin/bash
# The Welsh71 disc controllers (rtl/alt: fdc1772 + floppy, i8271) to Verilog-2001 for XST with sv2v
# (/opt/sv2v/sv2v): XST rejects their declarations in unnamed blocks. Output rtl/sv2v/ (in git, one
# file per module), used by the board .prj and measure/alt_*.prj. Run again after an edit of rtl/alt.
set -e
cd "$(dirname "$0")/.."
SV2V=${SV2V:-/opt/sv2v/sv2v}
OUT=rtl/sv2v
rm -rf $OUT && mkdir $OUT
$SV2V rtl/alt/fdc1772/fdc1772.v rtl/alt/fdc1772/floppy.v rtl/alt/i8271/i8271.v -w $OUT 2>&1 \
	| grep -v -E '^\s*$|Warning: Number literal|^ *[0-9]* \||^\s*\|' || true
ls $OUT
