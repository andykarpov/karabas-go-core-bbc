# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

An Acorn BBC Micro Model B / BBC Master 128 core for the Karabas Go, Mini and Mini G boards (Xilinx Spartan-6 XC6SLX25, ISE 14.7, XST): a port of [hoglet67/BeebFpga](https://github.com/hoglet67/BeebFpga) branch `dev` (9b73fea) with donor parts of [Welsh71/BBCMicro.Alternate_MiSTer](https://github.com/Welsh71/BBCMicro.Alternate_MiSTer) (01da28c): both CPUs muxed by `m128_mode`, the 8271 and 1770 disc controllers on `.ssd` / `.dsd` images, the UEF tape player. Docs, in Russian: `docs/PLAN.md` (research, decisions, phases, the Ф0 fit numbers). Follow the phases; record a changed decision in PLAN.md.

User decisions (2026-11-18): BeebFpga `dev` + the Welsh71 donor parts; discs both ways (MMFS on SD2 driven by the core, `.ssd` / `.dsd` from SD1 through the firmware); Model B and Master 128 in one core, each with its own CPU; ROMs built into the `.kg`; core id `bbc`, public repo.

## Layout

- `src/rtl/beeb/`: BeebFpga `src/common` as imported; `cpu/` = T65 and AlanD R65Cx2 from its AtomBusMon tree. `Tube/gen_flag_v3.v` is an include fragment (`-vlgincdir`), not a module.
- `src/rtl/alt/`: the Welsh71 files (i8271, fdc1772, tape, drive sounds, disk OSD).
- `src/roms/`: the BeebFpga ROM files (no `.bit`); `upstream/beebfpga/make_rom_image_tangnano.sh` shows the sideways ROM order.
- `src/measure/`, `src/Makefile`: the Ф0 XST fit checks (`make measure-master|measure-beeb`, `make measure-report`).
- `upstream/`: reference tops and docs (Spec Next, Tang 20K, Welsh71 core and MiSTer top), not built.

## Rules of the core

The rules of the other karabas-go cores apply: standard video timing with syncs always present, `FT_CLK_OUT` about 8 MHz on Mini / Mini G, Go `FDC_*` outputs 0 when unused, Mini / Mini G drive T3 (`FLASH_CS_N`) = 0, OSD switch index = item position unless `"index"`, an OSD value shows 10 characters at most, FL slots 0..7 only, Verilog-2001 for XST (`sv2v` for SV), VHDL-93 for XST, imported code marked `karabas:`.

- Licences: the BeebFpga core files are non-commercial only (allowed by the user), AtomBusMon / MMFS GPL-3, Welsh71 GPL-2+; keep every header as it is.
- **Ask the user before every check on the board** (and the HDMI capture). Ask before a firmware flash.
- One branch per phase of `docs/PLAN.md`, one PR at its end.
- Heavy builds: Mini G only while working on one feature, all boards for a release; map with cost table 2 first.

## Memory

The Claude Code memory of this repo is shared with all karabas-go repos: `~/.claude/projects/<this project>/memory` is a symlink to `../karabas-go-notes` (private repo `andykarpov/karabas-go-notes`). Its `MEMORY.md` is split by repo; commit and push it after every memory change.
