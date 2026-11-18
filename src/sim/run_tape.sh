#!/bin/bash
# bbc_tape + bbc_tape_sdram + tape_player (Welsh71) on a behavioural SDRAM: load a small UEF over LD_*,
# read it back, play it, count the edges of cas_out (a few seconds)
set -e
cd "$(dirname "$0")"
mkdir -p build
iverilog -g2012 -o build/tb_tape tb_tape.v sdram_model.v ../rtl/karabas/bbc_tape.v ../rtl/karabas/bbc_tape_sdram.v \
	../rtl/sv2v/tape_player.v ../../modules/rtl/mem/kg_fifo.v
vvp -n build/tb_tape | grep -v '\$finish'
