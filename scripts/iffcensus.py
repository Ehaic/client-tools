#!/usr/bin/env python3
"""IFF tag census - counts FORM/chunk tags in an SOE IFF file.

Usage: python iffcensus.py <file> [file2]
With two files, prints a side-by-side census diff (the TerrainEditor
round-trip verification style: structural comparison, not byte diff).
"""
import struct
import sys
from collections import Counter


def walk(data, offset, end, counts, depth=0):
    while offset + 8 <= end:
        tag = data[offset:offset + 4]
        size = struct.unpack('>I', data[offset + 4:offset + 8])[0]
        if tag == b'FORM':
            form_name = data[offset + 8:offset + 12]
            counts['FORM ' + form_name.decode('ascii', 'replace')] += 1
            walk(data, offset + 12, offset + 8 + size, counts, depth + 1)
        else:
            counts[tag.decode('ascii', 'replace')] += 1
        offset += 8 + size
    return counts


def census(path):
    with open(path, 'rb') as f:
        data = f.read()
    counts = Counter()
    walk(data, 0, len(data), counts)
    return counts, len(data)


def main():
    if len(sys.argv) == 2:
        counts, size = census(sys.argv[1])
        print(f'{sys.argv[1]}: {size} bytes')
        for tag, n in sorted(counts.items()):
            print(f'  {tag:16} {n}')
    elif len(sys.argv) == 3:
        a, asize = census(sys.argv[1])
        b, bsize = census(sys.argv[2])
        print(f'A: {sys.argv[1]} ({asize} bytes)')
        print(f'B: {sys.argv[2]} ({bsize} bytes)')
        tags = sorted(set(a) | set(b))
        same = True
        print(f'  {"tag":16} {"A":>8} {"B":>8}')
        for tag in tags:
            mark = '' if a.get(tag, 0) == b.get(tag, 0) else '   <-- DIFFERS'
            if mark:
                same = False
            print(f'  {tag:16} {a.get(tag, 0):>8} {b.get(tag, 0):>8}{mark}')
        print('census: IDENTICAL' if same else 'census: DIFFERS')
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
