#!/usr/bin/env python3
"""LUT / DSP48 / block RAM count per module of a netgen Verilog netlist (XST -keep_hierarchy Yes).

Usage: tools/lut_breakdown.py xst_hier/nl/hier.v
Counts are per module definition (own cells, not children); _INST_n copies are summed.
"""
import collections, re, sys

cur = None
cnt = {k: collections.Counter() for k in ("lut", "dsp", "ram")}
for line in open(sys.argv[1]):
    m = re.match(r"^module (\S+)", line)
    if m:
        cur = re.sub(r"_INST_\d+$", "", m.group(1))
        continue
    if re.match(r"^\s+LUT[1-6](_L|_D)?\s", line):
        cnt["lut"][cur] += 1
    elif re.match(r"^\s+DSP48A1\s", line):
        cnt["dsp"][cur] += 1
    elif re.match(r"^\s+RAMB(16|8)BWER\s", line):
        cnt["ram"][cur] += 1
print("total LUT", sum(cnt["lut"].values()))
for k, v in cnt["lut"].most_common():
    print(f"{v:6} {k:28} dsp={cnt['dsp'][k]} ram={cnt['ram'][k]}")
