# BBC Micro core for Karabas Go / Mini / Mini G

Acorn BBC Micro Model B and BBC Master 128 for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). A port of [BeebFpga](https://github.com/hoglet67/BeebFpga) by David Banks (hoglet67), based on earlier work by Mike Stirling, with the 8271 / 1770 disc controllers and UEF tape player of [BBCMicro.Alternate](https://github.com/Welsh71/BBCMicro.Alternate_MiSTer) by Paul Stewart (Welsh71).

Status: built for Karabas Go, Mini and Mini G (`src/bbc.kg`, one file for all three); checked on Mini G, Go and Mini have not run on a board yet. The plan and the history are in `docs/PLAN.md` (Russian), a Russian README is `README.ru.md`.

## Using the core

- **Models**: OSD *Model* = Model B (6502) or Master 128 (65C02). A change resets the machine.
- **Keyboard**: positional, as BeebFpga (the keys sit where they are on a BBC keyboard): F12 = BREAK, Shift+F12 = Shift+BREAK, PC `'` = BBC `:` (with Shift `*`), `=` = `^`, Shift+`2` = `"`.
- **SD card 2 (MMFS)**: put a `BEEB.MMB` file (for example the RetroClinic one) in the root of the second SD card, or `.ssd` files on a FAT card for MMFS2 (OSD *Disc FS*). `*DCAT`, `*DIN n`, `*CAT`.
- **Disc images (DFS)**: `.ssd` / `.dsd` in `/bbc` on the first SD card, OSD *Drive 0* / *Drive 1*. Model B uses the Intel 8271 (DFS 1.20) or the WD1770 (DFS 2.26), OSD *B FDC*; the Master its 1770. With *Disc FS* = MMFS+DFS, MMFS takes `*DISC`: choose *Disc FS* = DFS to use the images. Images are writable.
- **Cassette**: `.uef` in `/bbc`, OSD *Tape*, then `*TAPE` and `CHAIN""` (or `*RUN`). The image plays while the cassette motor is on; *Tape rewind* starts it again. Compressed UEFs (most files of the archives are gzip) must be unpacked first: `gunzip -c game.uef > game_raw.uef` (or `zcat`, 7-Zip). With no image the tape input of the board is used.
- **Co-processor**: OSD *Co-Pro* = 65C02 (Model B); on the Master the tube is set by `*CONFIGURE TUBE`.


## Licence

The files written for this port are GPL-3.0 (see [LICENSE](LICENSE)). Imported files keep the licence in their headers: the BeebFpga core files are licensed for **non-commercial use only** (BSD-style with a non-commercial clause), the BBCMicro.Alternate files are GPL-2.0-or-later, MMFS is GPL-3.0.

BBC Micro is a trademark of the BBC; Acorn ROMs are copyright of their owners. This project is not affiliated with the BBC or Acorn.
