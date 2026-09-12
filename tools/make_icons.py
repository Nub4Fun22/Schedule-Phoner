"""Generate launcher icon assets from the source burning-calendar image.

Produces:
  assets/icon/app_icon.png            1024x1024, dark ember background, full art
  assets/icon/app_icon_foreground.png 1024x1024, transparent, padded for the
                                      Android adaptive-icon safe zone.

Run from repo root:  python3 tools/make_icons.py
"""
from PIL import Image

SRC = "Calendar.png"
OUT_MAIN = "assets/icon/app_icon.png"
OUT_FG = "assets/icon/app_icon_foreground.png"

SIZE = 1024
# Matches flutter_launcher_icons.adaptive_icon_background in pubspec.yaml.
EMBER = (0x1A, 0x12, 0x07, 255)


def fit(img, box):
    """Return img scaled to fit within a box (w,h) preserving aspect ratio."""
    w, h = img.size
    bw, bh = box
    scale = min(bw / w, bh / h)
    return img.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                      Image.LANCZOS)


def main():
    src = Image.open(SRC).convert("RGBA")

    # --- Main icon: full art centered on the ember background, small margin ---
    main = Image.new("RGBA", (SIZE, SIZE), EMBER)
    margin = int(SIZE * 0.06)  # slight breathing room
    art = fit(src, (SIZE - 2 * margin, SIZE - 2 * margin))
    main.alpha_composite(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2))
    main.convert("RGB").save(OUT_MAIN)
    print(f"wrote {OUT_MAIN} {main.size}")

    # --- Adaptive foreground: transparent, art shrunk into the safe zone ---
    # Adaptive icons are masked; keep art within ~66% center circle/square.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    safe = int(SIZE * 0.62)
    art2 = fit(src, (safe, safe))
    fg.alpha_composite(art2, ((SIZE - art2.width) // 2, (SIZE - art2.height) // 2))
    fg.save(OUT_FG)
    print(f"wrote {OUT_FG} {fg.size}")


if __name__ == "__main__":
    main()
