#!/usr/bin/env python3
"""Generate Mathy app icons with M(y) calligraphic logo."""

from PIL import Image, ImageDraw, ImageFont
import os
import subprocess

ICON_DIR = os.path.join(
    os.path.dirname(__file__),
    "..", "Mathy", "Mathy", "Assets.xcassets", "AppIcon.appiconset"
)

MENU_BAR_DIR = os.path.join(
    os.path.dirname(__file__),
    "..", "Mathy", "Mathy", "Assets.xcassets", "MenuBarIcon.imageset"
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

# Menu bar icon sizes
MENU_BAR_SIZES = [
    ("menubar_icon.png", 18),
    ("menubar_icon@2x.png", 36),
]


def find_font():
    """Find a suitable font for the calligraphic M."""
    # Try fonts in order of preference for calligraphic look
    candidates = [
        "/System/Library/Fonts/Supplemental/Apple Chancery.ttf",
        "/System/Library/Fonts/Supplemental/Zapfino.ttf",
        "/System/Library/Fonts/Times.ttc",
        "/System/Library/Fonts/NewYork.ttf",
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


def generate_app_icon(size, font_path):
    """Generate a single app icon at the given pixel size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: gradient-like solid color (blue-purple)
    # Draw filled rounded rect for the background
    # macOS applies the squircle mask, so fill the whole square
    bg_color = (88, 86, 214)  # Purple-blue (similar to Apple's purple)
    draw.rectangle([0, 0, size, size], fill=bg_color)

    # Add a subtle gradient overlay (darker at top)
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    for y in range(size):
        alpha = int(40 * (1 - y / size))  # Darker at top
        overlay_draw.line([(0, y), (size, y)], fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # Text rendering
    text = "M(y)"  # Rendered in calligraphic font (Apple Chancery)

    # Font size relative to icon size
    font_size = int(size * 0.42)
    try:
        font = ImageFont.truetype(font_path, font_size)
    except Exception:
        font = ImageFont.load_default()

    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    x = (size - text_width) / 2 - bbox[0]
    y = (size - text_height) / 2 - bbox[1]

    # Draw text shadow for depth
    shadow_offset = max(1, size // 128)
    draw.text((x + shadow_offset, y + shadow_offset), text,
              fill=(0, 0, 0, 60), font=font)

    # Draw main text in white
    draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)

    return img


def generate_menu_bar_icon(size):
    """Generate a menu bar template icon (black on transparent)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    text = "M"  # Rendered in calligraphic font

    font_size = int(size * 0.75)
    font_path = find_font()
    try:
        font = ImageFont.truetype(font_path, font_size) if font_path else ImageFont.load_default()
    except Exception:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    x = (size - text_width) / 2 - bbox[0]
    y = (size - text_height) / 2 - bbox[1]

    # Menu bar icons should be black (system makes them template)
    draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)

    return img


def main():
    font_path = find_font()
    if font_path:
        print(f"Using font: {font_path}")
    else:
        print("Warning: No suitable font found, using default")

    # Generate app icons
    os.makedirs(ICON_DIR, exist_ok=True)
    for filename, size in ICON_SIZES:
        icon = generate_app_icon(size, font_path)
        path = os.path.join(ICON_DIR, filename)
        icon.save(path, "PNG")
        print(f"Generated {filename} ({size}x{size})")

    # Generate menu bar icons
    os.makedirs(MENU_BAR_DIR, exist_ok=True)
    for filename, size in MENU_BAR_SIZES:
        icon = generate_menu_bar_icon(size)
        path = os.path.join(MENU_BAR_DIR, filename)
        icon.save(path, "PNG")
        print(f"Generated {filename} ({size}x{size})")

    # Write Contents.json for menu bar imageset
    import json
    contents = {
        "images": [
            {
                "filename": "menubar_icon.png",
                "idiom": "universal",
                "scale": "1x"
            },
            {
                "filename": "menubar_icon@2x.png",
                "idiom": "universal",
                "scale": "2x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "template-rendering-intent": "template"
        }
    }
    with open(os.path.join(MENU_BAR_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("Generated MenuBarIcon Contents.json")

    print("\nDone! All icons generated.")


if __name__ == "__main__":
    main()
