#!/usr/bin/python3
#
# Copyright (c) 2019 Kristopher Ives
# Copyright (c) 2019 Harald Sitter <sitter@kde.org>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import bencode3
from hashlib import md5, sha1
import os
from time import time
from urllib.parse import urlparse
from bs4 import BeautifulSoup
import argparse
import pprint

parser = argparse.ArgumentParser(description='Convert a meta4 link to a torrent')
parser.add_argument('meta4', help="meta4 file input")
parser.add_argument('torrent', help="torrent file output")
parser.add_argument('--urlname', action='store_true', help="Use a name in the mirror list instead")
args = parser.parse_args()

meta4 = BeautifulSoup(open(args.meta4), 'xml')
name = meta4.file['name']
mirrorList = []

for node in meta4.file.select('url'):
    mirrorList.append(node.string.strip())

if args.urlname:
    url = urlparse(mirrorList[0])
    name = os.path.basename(url.path)

print("File:       ", name)
print("Mirrors:    ", len(mirrorList))

torrent = None
if os.path.isfile(args.torrent):
    with open(args.torrent, 'rb') as f:
        torrent = bencode3.bdecode(f.read())
else:
    fileSize = int(meta4.file.size.string)
    fileHash = meta4.file.select('hash[type=sha-1]')[0].text
    pieceSize = int(meta4.file.pieces['length'])
    pieceCount = 0
    pieceHashes = bytearray()

    for node in meta4.file.pieces.children:
        pieceHash = node.string.strip()

        if not pieceHash:
            continue

        pieceHashes += bytearray.fromhex(pieceHash)
        pieceCount += 1

    print("File Size:  ", fileSize)
    print("File Hash:  ", fileHash)
    print("Piece Size: ", pieceSize, "(", pieceSize * pieceCount, ")")
    print("Piece Count:", pieceCount)

    torrent = {
        'announce': 'udp://tracker.openbittorrent.com:80',
        'creation date': int(time()),
        'info': {
            'piece length': pieceSize,
            'pieces': bytes(pieceHashes),
            'name': name,
            'length': fileSize
        }
    }

torrent['url-list'] = mirrorList

encoded = bencode3.encode_dict(torrent, 'ascii')

with open(args.torrent, 'wb') as fp:
    fp.write(encoded)
