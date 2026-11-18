#!/bin/bash
# bbc_video_out: line / frame lengths and the de window with and without the syncs of the core (~20 s)
set -e
cd "$(dirname "$0")"
mkdir -p build
iverilog -g2005 -o build/tb_video_out tb_video_out.v ../rtl/karabas/bbc_video_out.v
vvp -n build/tb_video_out | grep -v '\$finish'
