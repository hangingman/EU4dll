module plugin.width_debug;

// Width measurement diagnostics (country-select triage,
// 2026-11-22). Opt-in: enabled only when the environment
// variable EU4DLL_WIDTH_DEBUG is exactly "1", mirroring the
// EU4DLL_GLYPH_DEBUG switch in plugin.glyph_table. When off,
// the two extern(C) entry points below return immediately and
// the hooks that call them behave exactly as before.
//
// What is recorded (fd 2, raw write, same style as the glyph
// debug output; the lines go to pattern_eu4jps.log because the
// DLL's stderr is that log in the eu4-run harness):
//
// - "[WIDTH-DEBUG] bitmap ...": one line per wide (code point
//   >= 0x100) glyph fetch inside CBitmapFont::GetWidthOfString
//   (the mainTextBitmapWidthV137 hook). Fields: font, code
//   point, the glyph xadvance the fetch contributes (0 on a
//   miss), the string pointer and byte index of the fetch, and
//   acc = the XMM1 accumulator (sum of advance * scale so far,
//   BEFORE this glyph) read at the fetch site. Summing adv over
//   one string's lines gives the measured advance total the
//   game works with; acc shows the game's own running total.
// - "[WIDTH-DEBUG] rtt ...": one line per wide glyph fetch in
//   the CBitmapFont::RenderToTexture measuring / line-break
//   pass (site 1 hook). Fields as above, plus word / line =
//   the two float accumulators the pass keeps on its stack
//   (0x4(%rsp) word width, 0x20(%rsp) line width, both BEFORE
//   this glyph; verified by disassembly at VA 0x204ef6a) and
//   limit = the float at 0x2c(%rsp), which the pass compares
//   the accumulators against with ucomiss at its word-boundary
//   checks (VA 0x204edb2 / 0x204f062 / 0x204f137) and is
//   therefore the candidate box width. scale = the font's
//   float scale at font+0x940, applied to every advance.
// - "[WIDTH-DEBUG] string ...": emitted once per measured
//   string (when a fetch with index 0 is seen): the string
//   pointer, its byte length up to the NUL (scan capped at
//   512) and the first 48 bytes as hex, so the per-glyph lines
//   can be tied to an actual text. The raw bytes are the
//   Clausewitz escape form, as the game holds them.
//
// Latin fetches (code point < 0x100) are not logged: the two
// defects under investigation are about Japanese text, and
// logging every Latin fetch of every UI label would flood the
// log. A process-wide cap (widthDebugMaxLines) stops the
// output if a long session measures more than expected.
//
// This is a temporary diagnostic, like the item 31/32 glyph
// debug; it changes no game behaviour.

enum size_t widthDebugMaxLines = 50_000;
enum size_t widthDebugStringScanCap = 512;
enum size_t widthDebugStringHexBytes = 48;

private __gshared int g_widthDebugState; // 0 unknown, 1 off, 2 on
private __gshared size_t g_widthDebugLines;

bool widthDebugEnabled()
{
    if (g_widthDebugState == 0)
    {
        import core.stdc.stdlib : getenv;

        auto v = getenv("EU4DLL_WIDTH_DEBUG");
        g_widthDebugState = (v !is null && v[0] == '1' && v[1] == 0) ? 2 : 1;
    }
    return g_widthDebugState == 2;
}

private bool widthDebugRoom()
{
    return g_widthDebugLines < widthDebugMaxLines;
}

private void widthDebugWrite(string line)
{
    import core.sys.posix.unistd : write;

    write(2, line.ptr, line.length);
    g_widthDebugLines++;
}

float widthDebugFloatFromBits(uint bits)
{
    uint tmp = bits;
    return *cast(float*) &tmp;
}

private string widthDebugHexBytes(const(ubyte)[] bytes)
{
    import std.format : format;

    string hex;
    foreach (b; bytes)
    {
        if (hex.length)
            hex ~= " ";
        hex ~= format("%02x", b);
    }
    return hex.length ? hex : "-";
}

// Pure formatters, unit-tested below.

string formatWidthBitmapLine(size_t font, uint codePoint, int advance,
        bool hit, size_t str, size_t index, uint accBits)
{
    import std.format : format;

    return format("[WIDTH-DEBUG] bitmap font=0x%x cp=0x%x adv=%d hit=%d str=0x%x idx=%d acc=%.2f\n",
            font, codePoint, advance, hit ? 1 : 0, str, index,
            widthDebugFloatFromBits(accBits));
}

string formatWidthRttLine(size_t font, uint codePoint, int advance,
        bool hit, size_t str, uint index, uint wordBits, uint lineBits,
        uint limitBits, uint scaleBits)
{
    import std.format : format;

    return format("[WIDTH-DEBUG] rtt font=0x%x cp=0x%x adv=%d hit=%d str=0x%x idx=%d word=%.2f line=%.2f limit=%.2f scale=%.3f\n",
            font, codePoint, advance, hit ? 1 : 0, str, index,
            widthDebugFloatFromBits(wordBits),
            widthDebugFloatFromBits(lineBits),
            widthDebugFloatFromBits(limitBits),
            widthDebugFloatFromBits(scaleBits));
}

string formatWidthStringLine(string kind, size_t str,
        const(ubyte)[] bytes, size_t totalLength)
{
    import std.format : format;

    return format("[WIDTH-DEBUG] string kind=%s str=0x%x len=%d bytes=%s\n",
            kind, str, totalLength, widthDebugHexBytes(bytes));
}

// Scan a measured string (NUL-terminated in practice; capped)
// and emit its identity line. Called on an index-0 fetch.
private void widthDebugLogString(string kind, const(char)* str)
{
    if (str is null)
        return;
    ubyte[] buf;
    size_t total = 0;
    foreach (i; 0 .. widthDebugStringScanCap)
    {
        const b = cast(ubyte) str[i];
        if (b == 0)
            break;
        total++;
        if (i < widthDebugStringHexBytes)
            buf ~= b;
    }
    if (widthDebugRoom())
        widthDebugWrite(formatWidthStringLine(kind, cast(size_t) str, buf, total));
}

// Called from mainTextBitmapWidthV137_hook for wide fetches.
// advance is the glyph xadvance at glyph+0xC (the value the
// reproduced movswl loads); hit is false when the glyph was
// null (the fetch contributes nothing). accBits is the bit
// pattern of the XMM1 accumulator before this glyph.
extern (C) void widthDebugBitmapWidth(size_t font, uint codePoint,
        int advance, bool hit, const(char)* str, size_t index, uint accBits)
{
    if (!widthDebugEnabled() || codePoint < 0x100)
        return;
    if (index == 0)
        widthDebugLogString("bitmap", str);
    if (widthDebugRoom())
        widthDebugWrite(formatWidthBitmapLine(font, codePoint, advance,
                hit, cast(size_t) str, index, accBits));
}

// Called from mainTextRenderToTextureV137Site1_hook (wide
// path only, after the glyph lookup). strStart is the start of
// the measured string, reconstructed by the hook as
// charPtr - index. wordBits / lineBits / limitBits are the
// float stack slots described at the top; scaleBits is the
// font scale float.
extern (C) void widthDebugRttMeasure(size_t font, uint codePoint,
        int advance, bool hit, const(char)* strStart, uint index,
        uint wordBits, uint lineBits, uint limitBits, uint scaleBits)
{
    if (!widthDebugEnabled() || codePoint < 0x100)
        return;
    if (index == 0)
        widthDebugLogString("rtt", strStart);
    if (widthDebugRoom())
        widthDebugWrite(formatWidthRttLine(font, codePoint, advance,
                hit, cast(size_t) strStart, index, wordBits, lineBits,
                limitBits, scaleBits));
}

unittest
{
    // Bit-cast helper: 12.5f and 0.85f patterns.
    assert(widthDebugFloatFromBits(0x4148_0000) == 12.5f);
    assert(widthDebugFloatFromBits(0) == 0.0f);

    const bl = formatWidthBitmapLine(0x1234, 0x308B, 15, true,
            0x5000, 3, 0x4148_0000);
    assert(bl == "[WIDTH-DEBUG] bitmap font=0x1234 cp=0x308b adv=15 hit=1 str=0x5000 idx=3 acc=12.50\n");
    const blMiss = formatWidthBitmapLine(0x1234, 0x2026, 0, false,
            0x5000, 0, 0);
    assert(blMiss == "[WIDTH-DEBUG] bitmap font=0x1234 cp=0x2026 adv=0 hit=0 str=0x5000 idx=0 acc=0.00\n");

    const rl = formatWidthRttLine(0x1234, 0x308B, 15, true, 0x5000, 3,
            0x4148_0000, 0x41C8_0000, 0x4348_0000, 0x3F51_47AE);
    assert(rl == "[WIDTH-DEBUG] rtt font=0x1234 cp=0x308b adv=15 hit=1 str=0x5000 idx=3 word=12.50 line=25.00 limit=200.00 scale=0.817\n");

    const sl = formatWidthStringLine("rtt", 0x5000, [0x10, 0x26, 0x20], 3);
    assert(sl == "[WIDTH-DEBUG] string kind=rtt str=0x5000 len=3 bytes=10 26 20\n");
    const slEmpty = formatWidthStringLine("bitmap", 0x5000, [], 0);
    assert(slEmpty == "[WIDTH-DEBUG] string kind=bitmap str=0x5000 len=0 bytes=-\n");
}
