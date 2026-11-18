#!/usr/bin/env python3
"""BEEB.MMB helper for tests: list the disc titles, extract a disc as .ssd, make a blank DFS .ssd.

  tools/mmb.py list BEEB.MMB [pattern]      number, title of each disc (from the MMB header)
  tools/mmb.py get BEEB.MMB N out.ssd       disc N (200 KB, 80 tracks x 10 sectors x 256 bytes)
  tools/mmb.py blank out.ssd [title]        an empty DFS catalogue, 800 sectors

MMB: 16 header entries of 16 bytes per 8 KB header block (entry 0 = the boot drives), then
511 discs of 204800 bytes; the title is 12 bytes, byte 15 the status (0xF0 unformatted).
"""
import sys

DISC = 204800


def titles(path):
    with open(path, 'rb') as f:
        hdr = f.read(8192)
    for n in range(511):
        e = hdr[16 * (n + 1):16 * (n + 2)]
        if e[15] == 0xF0:
            continue
        yield n, e[:12].split(b'\0')[0].decode('latin-1').rstrip()


def main():
    cmd = sys.argv[1]
    if cmd == 'list':
        pat = sys.argv[3].upper() if len(sys.argv) > 3 else ''
        for n, t in titles(sys.argv[2]):
            if pat in t.upper():
                print(n, t)
    elif cmd == 'get':
        n = int(sys.argv[3])
        with open(sys.argv[2], 'rb') as f:
            f.seek(8192 + n * DISC)
            data = f.read(DISC)
        open(sys.argv[4], 'wb').write(data)
    elif cmd == 'blank':
        title = (sys.argv[3] if len(sys.argv) > 3 else 'BLANK').encode()[:12].ljust(12, b'\0')
        img = bytearray(DISC)
        img[0:8] = title[:8]
        img[256:260] = title[8:12]
        img[256 + 4] = 0      # cycle number
        img[256 + 5] = 0      # 8 x number of files
        img[256 + 6] = 0x03   # boot option 0, sectors bits 9..8 (800 = 0x320)
        img[256 + 7] = 0x20
        open(sys.argv[2], 'wb').write(img)
    else:
        sys.exit(__doc__)


main()
