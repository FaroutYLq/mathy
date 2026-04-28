#!/usr/bin/env python3
"""Generate Mathy app icons from SVG source files.

Renders the master SVG to PNGs at all required macOS icon sizes using
a Swift/AppKit helper for native font and SVG rendering.
The menu bar icon uses SVG directly in the Xcode asset catalog.
"""

import json
import os
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SVG_SOURCE = os.path.join(PROJECT_ROOT, "assets", "icon.svg")
MENUBAR_SVG = os.path.join(PROJECT_ROOT, "assets", "menubar_icon.svg")
RENDER_SWIFT = os.path.join(SCRIPT_DIR, "render_svg.swift")

ICON_DIR = os.path.join(
    PROJECT_ROOT, "Mathy", "Mathy", "Assets.xcassets", "AppIcon.appiconset"
)
MENU_BAR_DIR = os.path.join(
    PROJECT_ROOT, "Mathy", "Mathy", "Assets.xcassets", "MenuBarIcon.imageset"
)

# macOS app icon sizes: (filename, pixel_size)
ICON_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def render_svg_to_png(svg_path, png_path, size):
    """Render SVG to PNG at the given size using Swift/AppKit."""
    result = subprocess.run(
        ["swift", RENDER_SWIFT, svg_path, png_path, str(size)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"  Error: {result.stderr.strip()}", file=sys.stderr)
        return False
    return True


def main():
    if not os.path.exists(SVG_SOURCE):
        print(f"Error: SVG source not found at {SVG_SOURCE}", file=sys.stderr)
        sys.exit(1)

    print(f"Source: {SVG_SOURCE}")

    # Generate app icon PNGs from SVG
    os.makedirs(ICON_DIR, exist_ok=True)
    for filename, size in ICON_SIZES:
        path = os.path.join(ICON_DIR, filename)
        if render_svg_to_png(SVG_SOURCE, path, size):
            print(f"  {filename} ({size}x{size})")
        else:
            print(f"  FAILED: {filename}")

    # Copy menu bar SVG into asset catalog
    os.makedirs(MENU_BAR_DIR, exist_ok=True)
    dest = os.path.join(MENU_BAR_DIR, "menubar_icon.svg")
    shutil.copy2(MENUBAR_SVG, dest)
    print(f"\nMenu bar: copied menubar_icon.svg")

    # Remove old PNG menu bar icons
    for old in ["menubar_icon.png", "menubar_icon@2x.png"]:
        old_path = os.path.join(MENU_BAR_DIR, old)
        if os.path.exists(old_path):
            os.remove(old_path)
            print(f"  Removed old {old}")

    # Write Contents.json for menu bar imageset (SVG version)
    contents = {
        "images": [
            {
                "filename": "menubar_icon.svg",
                "idiom": "universal"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "preserves-vector-representation": True,
            "template-rendering-intent": "template"
        }
    }
    contents_path = os.path.join(MENU_BAR_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")
    print("  Updated Contents.json for SVG")

    print("\nDone!")


if __name__ == "__main__":
    main()
