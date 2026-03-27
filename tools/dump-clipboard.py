#!/usr/bin/env python3
"""
Dump all clipboard representations to files for use as test fixtures.

Usage:
  1. Copy something from Word, a browser, etc.
  2. Run: python3 tools/dump-clipboard.py
  3. Check the output/ directory for dumped files.
"""

import os
import sys
import AppKit

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "clipboard-dump")
os.makedirs(OUTPUT_DIR, exist_ok=True)

pb = AppKit.NSPasteboard.generalPasteboard()
types = pb.types()

if not types:
    print("Clipboard is empty.")
    sys.exit(0)

print(f"Found {len(types)} type(s) on the clipboard:\n")

for t in types:
    safe_name = t.replace("/", "_").replace(".", "_")
    data = pb.dataForType_(t)
    if not data:
        print(f"  {t}: (no data)")
        continue

    raw = bytes(data)
    size = len(raw)

    # Try to decode as UTF-8 text
    try:
        text = raw.decode("utf-8")
        ext = "txt"
        if "html" in t.lower():
            ext = "html"
        elif "rtf" in t.lower():
            ext = "rtf"
        path = os.path.join(OUTPUT_DIR, f"{safe_name}.{ext}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"  {t}: {size} bytes -> {os.path.relpath(path)}")
    except UnicodeDecodeError:
        path = os.path.join(OUTPUT_DIR, f"{safe_name}.bin")
        with open(path, "wb") as f:
            f.write(raw)
        print(f"  {t}: {size} bytes (binary) -> {os.path.relpath(path)}")

print(f"\nDumped to: {OUTPUT_DIR}/")
print("\nTo use as a test fixture, copy the HTML content from the .html file")
print("and paste it into a test case in test/tests.m")
