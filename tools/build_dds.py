#!/usr/bin/env python3
"""Build a DXT5 DDS with a manual mip chain: each level is produced by
successive BOX reduction of the source PNG, encoded to DXT5 on its own
(ImageMagick, mipmaps=0), then concatenated behind a hand-written header.
This keeps the mip alpha close to a true box reduction of the source
(ImageMagick's one-shot mip generation bled alpha: coverage +0.16 too
wide at display size in the prototype-1 investigation).

Usage: build_dds.py <src.png> <out.dds> [workdir]
Also verifies: decodes every level back out of the assembled DDS and
compares mean alpha / coverage against the expected box-reduced level,
for the whole atlas and for the U+56FD glyph rect (from the .fnt next
to the PNG, if present).
"""
import os, struct, subprocess, sys, tempfile
from PIL import Image

GLYPH_ID = 22269  # U+56FD


def dxt5_size(w, h):
    return max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * 16


def header(w, h, linear, mips):
    flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000
    pf = struct.pack("<I I 4s I I I I I", 32, 0x4, b"DXT5", 0, 0, 0, 0, 0)
    caps = 0x1000 | 0x400000 | 0x8
    return (b"DDS " + struct.pack("<I I I I I I I", 124, flags, h, w, linear, 0, mips)
            + b"\x00" * 44 + pf + struct.pack("<I I I I I", caps, 0, 0, 0, 0))


def encode_level(img, tmp):
    p = os.path.join(tmp, "lvl.png")
    d = os.path.join(tmp, "lvl.dds")
    img.save(p)
    subprocess.run(["magick", p, "-define", "dds:compression=dxt5",
                    "-define", "dds:mipmaps=0", d], check=True)
    data = open(d, "rb").read()
    assert data[:4] == b"DDS " and data[84:88] == b"DXT5", "unexpected dds layout"
    payload = data[128:]
    exp = dxt5_size(img.size[0], img.size[1])
    assert len(payload) == exp, (len(payload), exp, img.size)
    return payload


def decode_level(payload, w, h, tmp):
    d = os.path.join(tmp, "one.dds")
    p = os.path.join(tmp, "one.png")
    with open(d, "wb") as f:
        f.write(header(w, h, len(payload), 1))
        f.write(payload)
    subprocess.run(["magick", d, p], check=True)
    return Image.open(p).convert("RGBA")


def stats(alpha_img, box=None):
    a = alpha_img
    if box:
        a = a.crop(box)
    hist = a.histogram()
    n = sum(hist)
    mean = sum(v * c for v, c in enumerate(hist)) / n
    cov128 = sum(hist[128:]) / n
    cov0 = (n - hist[0]) / n
    return mean, cov128, cov0


def glyph_rect(fnt_path):
    with open(fnt_path, encoding="utf-8") as f:
        for line in f:
            parts = line.split()
            if parts and parts[0] == "char":
                d = dict(p.split("=", 1) for p in parts[1:] if "=" in p)
                if int(d["id"]) == GLYPH_ID:
                    return (int(d["x"]), int(d["y"]), int(d["width"]), int(d["height"]))
    return None


def main():
    src, out = sys.argv[1], sys.argv[2]
    tmp = sys.argv[3] if len(sys.argv) > 3 else tempfile.mkdtemp(prefix="ddsbuild")
    os.makedirs(tmp, exist_ok=True)
    img0 = Image.open(src).convert("RGBA")
    levels = [img0]
    while levels[-1].size != (1, 1):
        w, h = levels[-1].size
        nw, nh = max(1, w // 2), max(1, h // 2)
        if (nw, nh) == (w, h):
            break
        levels.append(levels[-1].resize((nw, nh), Image.BOX))
    payloads = [encode_level(lvl, tmp) for lvl in levels]
    with open(out, "wb") as f:
        f.write(header(img0.size[0], img0.size[1], len(payloads[0]), len(levels)))
        for p in payloads:
            f.write(p)
    print("levels=%d sizes=%s total_bytes=%d" % (
        len(levels), [l.size for l in levels],
        128 + sum(len(p) for p in payloads)))

    rect = None
    fnt = os.path.splitext(src)[0] + ".fnt"
    if os.path.exists(fnt):
        rect = glyph_rect(fnt)
    print("glyph U+56FD rect:", rect)
    print("lvl | atlas meanA exp/dec diff | atlas cov128 exp/dec diff | glyph meanA exp/dec diff | glyph cov128 exp/dec diff | glyph cov>0 exp/dec diff")
    off = 128
    raw = open(out, "rb").read()
    for i, lvl in enumerate(levels):
        w, h = lvl.size
        plen = len(payloads[i])
        dec = decode_level(raw[off:off + plen], w, h, tmp)
        off += plen
        ea = lvl.split()[3]
        da = dec.split()[3]
        am_e, ac_e, _ = stats(ea)
        am_d, ac_d, _ = stats(da)
        line = "%d (%dx%d) | %.3f/%.3f %+.3f | %.5f/%.5f %+.5f" % (
            i, w, h, am_e, am_d, am_d - am_e, ac_e, ac_d, ac_d - ac_e)
        if rect:
            gx, gy, gw, gh = rect
            s = 1 << i
            box = (gx // s, gy // s, gx // s + max(1, gw // s), gy // s + max(1, gh // s))
            gm_e, gc_e, g0_e = stats(ea, box)
            gm_d, gc_d, g0_d = stats(da, box)
            line += " | %.2f/%.2f %+.2f | %.4f/%.4f %+.4f | %.4f/%.4f %+.4f" % (
                gm_e, gm_d, gm_d - gm_e, gc_e, gc_d, gc_d - gc_e, g0_e, g0_d, g0_d - g0_e)
        print(line, flush=True)
    print("VERIFY_DONE")


if __name__ == "__main__":
    main()
