#!/usr/bin/env python3
"""Console output helper shared by the Atlas repository CLIs.

These scripts print non-ASCII punctuation (em dash, ellipsis, arrow) in their
human-readable output. On Windows the interpreter attaches stdout to the active
console code page, which is normally cp1252. Em dash and ellipsis happen to
exist in cp1252 and merely render as replacement characters, but U+2192 does
not exist there at all, so `scripts/efficiency.py audit` died with
UnicodeEncodeError partway through printing its findings.

Forcing UTF-8 on the output streams keeps the intended characters on capable
terminals and, with `errors="replace"`, guarantees that a terminal which still
cannot represent a character degrades that character instead of killing a
validation run. CI already runs UTF-8 by default, so this is a no-op there.
"""

from __future__ import annotations

import sys


def use_utf8_output() -> None:
    """Encode stdout/stderr as UTF-8 regardless of the console code page.

    Safe to call more than once, and safe when the streams have been replaced
    by objects that do not support reconfiguration (pytest capture, pipes into
    another tool, redirected files).
    """
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):
            # A detached or already-closed stream is not worth failing a
            # validation run over; the caller's real work still runs.
            continue
