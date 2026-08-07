#!/usr/bin/env python3
"""Restore preserved Studio-only source and Workspace hierarchy beside this script."""
from pathlib import Path
import base64, gzip, io, tarfile
here=Path(__file__).resolve().parent
def joined(pattern):
    return ''.join(p.read_text().strip() for p in sorted(here.glob(pattern)))
# source hierarchy
data=base64.b64decode(joined('legacy-src.tar.gz.b64.part*'))
with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tf:
    tf.extractall(here, filter='data')
# workspace hierarchy index
w=base64.b64decode(joined('workspace-index.json.gz.b64.part*'))
(here/'workspace-index.json').write_bytes(gzip.decompress(w))
print('restored', here/'legacy-src')
print('restored', here/'workspace-index.json')
