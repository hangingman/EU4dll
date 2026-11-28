#!/usr/bin/env python3
"""Generate the EU4 map font (Mapfont.fnt + Mapfont.dds) with an
outlined glyph structure, following the layer structure measured in
the vanilla Mapfont texture and in screenshots of the JP mod:
- core: RGB 0 (black), alpha = coverage x 191/255 (vanilla encoding)
- white outline band: dilation of the coverage by 5 px, RGB
  (255,252,244), alpha up to 191, masked to where the core is absent
- thin black outer edge: a further 2 px dilation, RGB 0, alpha up
  to 170, masked to where the white band is absent
Source font is Noto Sans CJK JP Bold (face 0). Glyph cells grow by
7 px per side (xoffset/yoffset shift by -7, width/height +14);
xadvance and the glyph set are the same as the text fonts produced
by tools/generate_fonts.py (tools/font_charset.tsv UNION the vanilla
Mapfont ids, plus CP1252 duplicate registrations).

The atlas is written as a PNG and then converted to a DXT5 DDS with
a manual mip chain by tools/build_dds.py (run automatically at the
end). The DDS must stay under the 64 MiB texture file-size cap.

Paths can be overridden by environment variables:
EU4DLL_FONT_GAME_FONTS (vanilla gfx/fonts directory),
EU4DLL_FONT_CHARSET, EU4DLL_FONT_NOTO_BOLD and EU4DLL_FONT_OUTDIR.
"""
import os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

GAME_FONTS = os.environ.get("EU4DLL_FONT_GAME_FONTS", os.path.expanduser("~/.steam/debian-installation/steamapps/common/Europa Universalis IV/gfx/fonts"))
CHARSET = os.environ.get("EU4DLL_FONT_CHARSET", os.path.join(os.path.dirname(os.path.abspath(__file__)), "font_charset.tsv"))
OUTDIR = os.environ.get("EU4DLL_FONT_OUTDIR", os.path.expanduser("~/work/eu4-run/item23/gfx/fonts"))
NOTO_BOLD = os.environ.get("EU4DLL_FONT_NOTO_BOLD", "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc")

CORE_A = 191
WHITE_A = 191
EDGE_A = 170
WHITE_RGB = (255, 252, 244)
WHITE_R = 5   # dilation radius of the white outline band
EDGE_R = 2    # extra dilation radius of the black outer edge
GROW = WHITE_R + EDGE_R  # 7 px per side

EMPTY_CPS = {0x2007, 0x200B, 0xFE0E}
CP1252_DUP = {0x2014: 0x97, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2026: 0x85}


def parse_vanilla(name):
    info = {}
    chars = []
    with open(os.path.join(GAME_FONTS, name + ".fnt"), encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "info":
                for p in parts[1:]:
                    if "=" in p:
                        k, v = p.split("=", 1)
                        info[k] = v.strip('"')
            elif parts[0] == "common":
                for p in parts[1:]:
                    if "=" in p:
                        k, v = p.split("=", 1)
                        info["common_" + k] = v
            elif parts[0] == "char":
                d = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
                chars.append(int(d["id"]))
    return info, chars


def load_charset():
    m = {}
    with open(CHARSET, newline="", encoding="utf-8") as f:
        lines = f.read().splitlines()
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        cp = int(parts[-3].replace("U+", ""), 16)
        fid = int(parts[-2], 16)
        m[fid] = cp
        if cp in CP1252_DUP:
            m[cp] = cp
            m[CP1252_DUP[cp]] = cp
    return m


def dilate(img_l, radius):
    # PIL MaxFilter size is the full window: radius r -> size 2r+1
    return img_l.filter(ImageFilter.MaxFilter(2 * radius + 1))


def compose(cov_img):
    """coverage L image -> 3-layer RGBA image grown by GROW px per side."""
    w, h = cov_img.size
    padded = Image.new("L", (w + 2 * GROW, h + 2 * GROW), 0)
    padded.paste(cov_img, (GROW, GROW))
    dil_w = dilate(padded, WHITE_R)          # coverage dilated by 5
    dil_b = dilate(dil_w, EDGE_R)            # coverage dilated by 7
    C = np.asarray(padded).astype(np.float32)
    W = np.asarray(dil_w).astype(np.float32)
    B = np.asarray(dil_b).astype(np.float32)
    white_cov = W * (255.0 - C) / 255.0
    edge_cov = B * (255.0 - W) / 255.0
    # layers back -> front: edge, white, core; each (rgb, alpha 0..1)
    layers = [
        ((0.0, 0.0, 0.0), edge_cov * EDGE_A / 255.0 / 255.0),
        ((WHITE_RGB[0] / 255.0, WHITE_RGB[1] / 255.0, WHITE_RGB[2] / 255.0),
         white_cov * WHITE_A / 255.0 / 255.0),
        ((0.0, 0.0, 0.0), C * CORE_A / 255.0 / 255.0),
    ]
    out_a = np.zeros(C.shape, np.float32)
    out_r = np.zeros(C.shape, np.float32)
    out_g = np.zeros(C.shape, np.float32)
    out_b = np.zeros(C.shape, np.float32)
    for (lr, lg, lb), la in layers:
        na = la + out_a * (1.0 - la)
        safe = np.where(na > 0, na, 1.0)
        out_r = (lr * la + out_r * out_a * (1.0 - la)) / safe
        out_g = (lg * la + out_g * out_a * (1.0 - la)) / safe
        out_b = (lb * la + out_b * out_a * (1.0 - la)) / safe
        out_a = na
    rgba = np.stack([out_r, out_g, out_b, out_a], axis=-1)
    return Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")


def gen(name, charset_map):
    info, vanilla_ids = parse_vanilla(name)
    size = int(info["size"])
    bold = int(info.get("bold", "0"))
    ids = dict(charset_map)
    for vid in vanilla_ids:
        ids.setdefault(vid, vid)
    font = ImageFont.truetype(NOTO_BOLD, size, index=0)
    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    base = ascent
    dummy = ImageDraw.Draw(Image.new("L", (8, 8)))

    glyphs = []  # (fid, composed_img or None, xoffset, yoffset, xadvance)
    for fid in sorted(ids):
        cp = ids[fid]
        if cp in EMPTY_CPS or cp < 0x20:
            glyphs.append((fid, None, 0, base, 0 if cp in EMPTY_CPS else 4))
            continue
        ch = chr(cp)
        try:
            bbox = dummy.textbbox((0, 0), ch, font=font, anchor="ls")
        except Exception:
            glyphs.append((fid, None, 0, base, 0))
            continue
        xadv = round(dummy.textlength(ch, font=font))
        if bbox is None or bbox[2] <= bbox[0] or bbox[3] <= bbox[1]:
            glyphs.append((fid, None, 0, base, xadv))
            continue
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        img = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(img)
        d.text((-bbox[0], -bbox[1]), ch, font=font, fill=255, anchor="ls")
        composed = compose(img)
        glyphs.append((fid, composed, bbox[0] - GROW, base + bbox[1] - GROW, xadv))

    SP = 1
    ATLAS_W = 8192
    order = sorted(glyphs, key=lambda g: -(g[1].size[1] if g[1] else 0))
    x = y = SP
    row_h = 0
    placed = {}
    for fid, img, xo, yo, xa in order:
        if img is None:
            placed[fid] = (0, 0, 0, 0, xo, yo, xa)
            continue
        w, h = img.size
        if x + w + SP > ATLAS_W:
            x = SP
            y += row_h + SP
            row_h = 0
        placed[fid] = (x, y, w, h, xo, yo, xa)
        x += w + SP
        row_h = max(row_h, h)
    total_h = y + row_h + SP
    atlas_h = ((total_h + 15) // 16) * 16
    dds_est = atlas_w_bytes = ATLAS_W * atlas_h * 4 // 3 + 128
    print("packed total_h=%d atlas=%dx%d dds_est=%.1f MiB" % (
        total_h, ATLAS_W, atlas_h, dds_est / 1048576), flush=True)
    assert dds_est < 64 * 1048576, "DDS would exceed the 64 MiB loader cap"

    atlas = Image.new("RGBA", (ATLAS_W, atlas_h), (0, 0, 0, 0))
    by_id = {g[0]: g for g in glyphs}
    for fid, (x, y, w, h, xo, yo, xa) in placed.items():
        img = by_id[fid][1]
        if img is not None:
            atlas.paste(img, (x, y))

    os.makedirs(OUTDIR, exist_ok=True)
    atlas.save(os.path.join(OUTDIR, name + ".png"))
    lines = []
    lines.append('info face="Noto Sans CJK JP" size=%d bold=%d italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=8,8,8,8 spacing=1,1' % (size, bold))
    lines.append("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (line_height, base, ATLAS_W, atlas_h))
    for fid in sorted(placed):
        x, y, w, h, xo, yo, xa = placed[fid]
        if by_id[fid][1] is None:
            lines.append("char id=%-6d x=0     y=0     width=1     height=0     xoffset=0     yoffset=%d     xadvance=%d     page=0" % (fid, yo, xa))
        else:
            lines.append("char id=%-6d x=%-6d y=%-6d width=%-6d height=%-6d xoffset=%-6d yoffset=%-6d xadvance=%-6d page=0" % (fid, x, y, w, h, xo, yo, xa))
    with open(os.path.join(OUTDIR, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    if name == "Mapfont":
        build_dds = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_dds.py")
        subprocess.run([sys.executable, build_dds,
                        os.path.join(OUTDIR, name + ".png"),
                        os.path.join(OUTDIR, name + ".dds")], check=True)
    print("%s size=%d glyphs=%d atlas=%dx%d lineHeight=%d base=%d white_r=%d edge_r=%d" % (
        name, size, len(placed), ATLAS_W, atlas_h, line_height, base, WHITE_R, EDGE_R), flush=True)


def main():
    charset_map = load_charset()
    print("charset font ids:", len(charset_map), flush=True)
    gen("Mapfont", charset_map)
    print("DONE")


if __name__ == "__main__":
    main()
