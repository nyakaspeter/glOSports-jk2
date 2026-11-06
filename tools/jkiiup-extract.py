#!/usr/bin/env python3
# Extract the files of Raven's Jedi Outcast patch installers (JKIIUp103.exe,
# JKIIUp104.exe) without running them: the cabinet appended to the exe, after
# "1CNT" and a 4-byte seed, is each byte XORed with and then lowered by a table
# of 256 MSVC rand() words from that seed; inside is a plain MSZIP cabinet.
#   tools/jkiiup-extract.py JKIIUp104.exe outdir    (-> outdir/Common/GameData/base/assets2.pk3, ...)
import os, struct, sys, zlib

def decode(exe):
    d = open(exe, 'rb').read()
    pe = struct.unpack_from('<I', d, 0x3c)[0]
    nsec = struct.unpack_from('<H', d, pe + 6)[0]
    sec = pe + 24 + struct.unpack_from('<H', d, pe + 20)[0]
    end = max(sum(struct.unpack_from('<II', d, sec + 40 * k + 16)) for k in range(nsec))
    if d[end:end + 4] != b'1CNT':
        sys.exit('no 1CNT payload after the PE image')
    seed = struct.unpack_from('<I', d, end + 4)[0]
    table = []
    for _ in range(256):
        seed = (seed * 0x343fd + 0x269ec3) & 0xffffffff
        w = (seed >> 16) & 0x7fff
        table.append((w & 255, w >> 8))
    src = d[end + 8:]
    return bytes(((c ^ table[p & 255][0]) - table[p & 255][1]) & 255 for p, c in enumerate(src))

def extract(cab, out):
    sig, _, _, _, coffFiles, _, vmin, vmaj, nfolders, nfiles, flags = struct.unpack_from('<4sIIIIIBBHHH', cab, 0)
    assert sig == b'MSCF' and vmaj == 1, 'not a cabinet'
    off, cbF, cbD = 36, 0, 0
    if flags & 4:
        cbH, cbF, cbD = struct.unpack_from('<HBB', cab, off); off += 4 + cbH
    for bit in (1, 2):                      # previous / next cabinet names
        if flags & bit:
            for _ in range(2):
                off = cab.index(b'\0', off) + 1
    folders = []
    for _ in range(nfolders):
        coff, ndata, comp = struct.unpack_from('<IHH', cab, off); off += 8 + cbF
        folders.append((coff, ndata, comp))
    files, off = [], coffFiles
    for _ in range(nfiles):
        size, uoff, ifold = struct.unpack_from('<IIH', cab, off); off += 16
        e = cab.index(b'\0', off); files.append((cab[off:e].decode('latin1'), size, uoff, ifold)); off = e + 1
    for fi, (coff, ndata, comp) in enumerate(folders):
        assert comp & 15 == 1, 'only MSZIP folders are handled'
        data, o = bytearray(), coff
        for _ in range(ndata):
            _, cb, _ = struct.unpack_from('<IHH', cab, o); o += 8 + cbD
            blk = cab[o:o + cb]; o += cb
            assert blk[:2] == b'CK'
            z = zlib.decompressobj(-15, zdict=bytes(data[-32768:])) if data else zlib.decompressobj(-15)
            data += z.decompress(blk[2:])
        for name, size, uoff, ifold in files:
            if ifold == fi:
                p = os.path.join(out, *name.split('\\'))
                os.makedirs(os.path.dirname(p), exist_ok=True)
                open(p, 'wb').write(data[uoff:uoff + size])
                print(f'{size:10d} {name}')

if len(sys.argv) != 3:
    sys.exit(__doc__ if __doc__ else 'usage: jkiiup-extract.py JKIIUp104.exe outdir')
extract(decode(sys.argv[1]), sys.argv[2])
