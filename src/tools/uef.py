#!/usr/bin/env python3
"""Make an uncompressed UEF tape image (for the tests of the cassette) from files of a DFS disc image.

  tools/uef.py cat disc.ssd                     the files of side 0: name, load, exec, length
  tools/uef.py make disc.ssd out.uef NAME...    the files as BBC tape files, one after another

Tape files (the format of the MOS, 1200 baud): blocks of up to 256 bytes, each &2A, the name (1..10
characters) and 0, load (4), exec (4), block number (2), length (2), flag (bit 7 = the last block),
4 spare bytes, the header CRC (2, high byte first), the data, the data CRC; the CRC is CRC-16/XMODEM.
UEF: "UEF File!" 0, version 0.10, a carrier chunk (&0110, cycles of 2400 Hz) before each block (5 s
before a file, 0.25 s between blocks), the block in a data chunk (&0100).
"""
import struct
import sys


def crc16(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def dfs_files(path):
    d = open(path, 'rb').read()
    s0, s1 = d[0:256], d[256:512]
    n = s1[5] // 8
    for i in range(n):
        name = s0[8 + 8 * i:15 + 8 * i].decode('latin-1').rstrip()
        e = s1[8 + 8 * i:16 + 8 * i]
        hi = e[6]
        load = e[0] | e[1] << 8 | ((hi >> 2) & 3) << 16
        exe = e[2] | e[3] << 8 | ((hi >> 6) & 3) << 16
        length = e[4] | e[5] << 8 | ((hi >> 4) & 3) << 16
        sector = e[7] | (hi & 3) << 8
        # 18-bit addresses: &3xxxx means the I/O processor (&FFFFxxxx)
        if load >> 16 == 3:
            load |= 0xFFFF0000
        if exe >> 16 == 3:
            exe |= 0xFFFF0000
        yield name, load, exe, length, d[sector * 256:sector * 256 + length]


def chunk(cid, data):
    return struct.pack('<HI', cid, len(data)) + data


def tape_file(name, load, exe, data):
    out = []
    nb = max(1, (len(data) + 255) // 256)
    for b in range(nb):
        blk = data[b * 256:(b + 1) * 256]
        flag = 0x80 if b == nb - 1 else 0
        hdr = name.encode('latin-1')[:10] + b'\0' + struct.pack('<IIHHB', load, exe, b, len(blk), flag) + b'\0' * 4
        body = b'\x2a' + hdr + struct.pack('>H', crc16(hdr))
        if blk:
            body += blk + struct.pack('>H', crc16(blk))
        out.append(chunk(0x0110, struct.pack('<H', 12000 if b == 0 else 600)))
        out.append(chunk(0x0100, body))
    return b''.join(out)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    if sys.argv[1] == 'cat':
        for name, load, exe, length, _ in dfs_files(sys.argv[2]):
            print('%-9s %08X %08X %6d' % (name, load, exe, length))
    elif sys.argv[1] == 'make':
        files = {f[0].split('.')[-1].upper(): f for f in dfs_files(sys.argv[2])}
        uef = b'UEF File!\0' + bytes([10, 0])
        for want in sys.argv[4:]:
            f = files[want.upper()]
            uef += tape_file(want.upper(), f[1], f[2], f[4])
        uef += chunk(0x0110, struct.pack('<H', 2400))
        open(sys.argv[3], 'wb').write(uef)
    else:
        sys.exit(__doc__)


main()
