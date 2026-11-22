#!/usr/bin/env python3
"""Generate EU4 BMFont text fonts (.fnt + .tga) for the translation mod.

The adopted generation is DELTA=3: the raster size is reduced by 3 px
from each vanilla size. The owner compared the original, delta2 and
delta3 sets in game on 2026-11-22 and adopted delta3. See
memory-bank/details/font_size_survey.md (sections 6 and 7) for the
survey and the decision. EU4DLL_FONT_DELTA overrides DELTA for
experiments, but the Debian package build rejects any font set whose
info sizes are not the delta3 values.

Method decided in item 22 (memory-bank/details/charset_and_font_generation.md):
Pillow + fontTools, source Noto Sans CJK JP (Regular / Bold TTC, face 0),
vanilla .fnt form (info / common / char lines, no page/chars lines, no
kernings; texture name follows the .fnt basename).

Glyph set per font = translation charset font ids (tools/font_charset.tsv,
override with EU4DLL_FONT_CHARSET) UNION that font's own vanilla ids,
plus CP1252 duplicate registrations.

Paths can be overridden by environment variables: EU4DLL_FONT_GAME_FONTS
(vanilla gfx/fonts directory), EU4DLL_FONT_CHARSET, EU4DLL_FONT_NOTO_REG,
EU4DLL_FONT_NOTO_BOLD and EU4DLL_FONT_OUTDIR.
"""
import csv, os, sys
from PIL import Image, ImageDraw, ImageFont

GAME_FONTS = os.environ.get("EU4DLL_FONT_GAME_FONTS", os.path.expanduser("~/.steam/debian-installation/steamapps/common/Europa Universalis IV/gfx/fonts"))
CHARSET = os.environ.get("EU4DLL_FONT_CHARSET", os.path.join(os.path.dirname(os.path.abspath(__file__)), "font_charset.tsv"))
OUTDIR = os.environ.get("EU4DLL_FONT_OUTDIR", os.path.expanduser("~/work/eu4-run/item23/gfx/fonts"))
DELTA = int(os.environ.get("EU4DLL_FONT_DELTA", "3"))
NOTO_REG = os.environ.get("EU4DLL_FONT_NOTO_REG", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")
NOTO_BOLD = os.environ.get("EU4DLL_FONT_NOTO_BOLD", "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc")

# name -> tint RGB (vanilla textures measured: white, grey 166, black)
TARGETS = {
    "vic_18": (255, 255, 255),
    "vic_18_grey": (166, 166, 166),
    "standard": (255, 255, 255),
    "standard_18": (255, 255, 255),
    "vic_22": (255, 255, 255),
    "vic_22_bl": (0, 0, 0),
    "standard_22": (255, 255, 255),
    "vic_29": (255, 255, 255),
    "vic_36": (255, 255, 255),
    "Arial12": (255, 255, 255),
    "garamond_12": (255, 255, 255),
    "garamond_14": (255, 255, 255),
    "garamond_14_bold": (255, 255, 255),
    "garamond_16": (255, 255, 255),
    "garamond_16_bold": (255, 255, 255),
    "garamond_24": (255, 255, 255),
}
# characters with no glyph in Noto Sans CJK JP (item 22): empty zero-width form
EMPTY_CPS = {0x2007, 0x200B, 0xFE0E}
# CP1252 specials: char -> duplicate byte id (in addition to its code point id)
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
    """returns dict font_id -> unicode code point to render"""
    m = {}
    with open(CHARSET, newline="", encoding="utf-8") as f:
        lines = f.read().splitlines()
    for line in lines[1:]:  # skip header; char itself may be a tab, so take last 3 fields
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        cp = int(parts[-3].replace("U+", ""), 16)
        fid = int(parts[-2], 16)
        m[fid] = cp
        if cp in CP1252_DUP:
            # tsv registers these at the CP1252 byte id; item 22 decision is
            # to register at BOTH the byte id and the Unicode code point.
            m[cp] = cp
            m[CP1252_DUP[cp]] = cp
    return m


def gen(name, tint, charset_map):
    info, vanilla_ids = parse_vanilla(name)
    size = max(9, int(info["size"]) - DELTA)
    bold = int(info.get("bold", "0"))
    line_height = int(info["common_lineHeight"])
    base = int(info["common_base"])
    ids = dict(charset_map)
    for vid in vanilla_ids:
        ids.setdefault(vid, vid)  # vanilla id == code point for U+0020-00FF set
    font_path = NOTO_BOLD if bold else NOTO_REG
    font = ImageFont.truetype(font_path, size, index=0)
    # PoC (item 22) precedent: lineHeight/base come from the source font's
    # own metrics at this size (Noto at 18px: ascent 21 + descent 6 = 27),
    # not from the vanilla Garamond metrics (18/13), which are too small
    # for Noto's em box and would give negative yoffsets.
    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    base = ascent
    dummy = ImageDraw.Draw(Image.new("L", (8, 8)))

    glyphs = []  # (fid, mask_image_or_None, xoffset, yoffset, xadvance)
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
        # anchor ls origin is (0, baseline); text drawn at (-bbox0,-bbox1) in
        # image coords where y is measured from the anchor point, so shift:
        # PIL draws relative to the given xy with anchor, hence the mask above
        # is correct as long as xy compensates the bbox offset.
        glyphs.append((fid, img, bbox[0], base + bbox[1], xadv))

    # shelf packing, tallest first, spacing 2 like vanilla; try every width
    # and keep the smallest-area atlas (keeps the .tga small and the height
    # at or below 4096 so the texture stays well under the size limits)
    SP = 2
    order = sorted(glyphs, key=lambda g: -(g[1].size[1] if g[1] else 0))
    best = None
    for atlas_w in (1024, 2048, 4096):
        x = y = SP
        row_h = 0
        placed = {}
        ok = True
        for fid, img, xo, yo, xa in order:
            if img is None:
                placed[fid] = (0, 0, 0, 0, xo, yo, xa)
                continue
            w, h = img.size
            if x + w + SP > atlas_w:
                x = SP
                y += row_h + SP
                row_h = 0
            if y + h + SP > 4096:
                ok = False
                break
            placed[fid] = (x, y, w, h, xo, yo, xa)
            x += w + SP
            row_h = max(row_h, h)
        if not ok:
            continue
        atlas_h = 1
        total_h = y + row_h + SP
        while atlas_h < total_h:
            atlas_h *= 2
        area = atlas_w * atlas_h
        if best is None or area < best[0]:
            best = (area, atlas_w, atlas_h, placed)
    if best is None:
        raise RuntimeError("packing failed for " + name)
    _, atlas_w, atlas_h, placed = best

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (tint[0], tint[1], tint[2], 0))
    by_id = {g[0]: g for g in glyphs}
    for fid, (x, y, w, h, xo, yo, xa) in placed.items():
        img = by_id[fid][1]
        if img is not None:
            solid = Image.new("RGBA", img.size, (tint[0], tint[1], tint[2], 255))
            solid.putalpha(img)
            atlas.paste(solid, (x, y))

    os.makedirs(OUTDIR, exist_ok=True)
    atlas.save(os.path.join(OUTDIR, name + ".tga"))
    lines = []
    lines.append('info face="Noto Sans CJK JP" size=%d bold=%d italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=2,2' % (size, bold))
    lines.append("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (line_height, base, atlas_w, atlas_h))
    for fid in sorted(placed):
        x, y, w, h, xo, yo, xa = placed[fid]
        if by_id[fid][1] is None:
            lines.append("char id=%-6d x=0     y=0     width=1     height=0     xoffset=0     yoffset=%d     xadvance=%d     page=0" % (fid, yo, xa))
        else:
            lines.append("char id=%-6d x=%-6d y=%-6d width=%-6d height=%-6d xoffset=%-6d yoffset=%-6d xadvance=%-6d page=0" % (fid, x, y, w, h, xo, yo, xa))
    with open(os.path.join(OUTDIR, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("%s size=%d bold=%d glyphs=%d atlas=%dx%d" % (name, size, bold, len(placed), atlas_w, atlas_h), flush=True)


def main():
    charset_map = load_charset()
    print("charset font ids:", len(charset_map), flush=True)
    only = sys.argv[1:] or None
    for name, tint in TARGETS.items():
        if only and name not in only:
            continue
        gen(name, tint, charset_map)
    print("DONE")


if __name__ == "__main__":
    main()
