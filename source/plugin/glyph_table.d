module plugin.glyph_table;

// Wide glyph side table (item 28, implementation step 1).
//
// Pure storage for glyph pointers whose code point does not fit
// the game's embedded 256-entry table (CBitmapFont + 0x100,
// item 26). For code points >= 0x100, ParseFontFile registration
// and every glyph fetch must go through this table instead of
// the embedded table; for code points < 0x100 nothing changes
// and this module refuses the entry, so callers cannot
// accidentally shadow a vanilla glyph.
//
// Design: memory-bank/details/glyph_table_expansion_item28.md
// Key: (font base pointer, code point). Value: the
// CBitmapCharacter* pointer the game allocated (0x10 bytes).
// Ownership stays with the game allocation; this table only
// stores the pointer and never frees the glyph. Wide glyphs
// therefore leak until process exit, as accepted in the design
// (bounded, about 0.75 MiB across all generated fonts).
//
// This step is storage only: no patch, no hook and no game
// memory access. The ParseFontFile redirect (step 2) and the
// item 19 fetch-site change (step 3) use the extern(C)
// wrappers at the bottom, whose signatures are plain
// (size_t, uint, void*) so naked-asm trampolines can call
// them without D types crossing the boundary.

enum uint wideGlyphThreshold = 0x100;

bool isWideCodePoint(uint codePoint)
{
    return codePoint >= wideGlyphThreshold;
}

struct GlyphKey
{
    size_t fontBase;
    uint codePoint;
}

struct WideGlyphTable
{
    private void*[GlyphKey] entries;

    // Register a wide glyph. Returns false (and keeps the
    // existing entry) when the code point is not wide, the
    // glyph pointer is null, or the key is already present;
    // the caller uses the false case for the game's Duplicate
    // path, mirroring the embedded table's occupied check.
    bool registerGlyph(size_t fontBase, uint codePoint, void* glyph)
    {
        if (!isWideCodePoint(codePoint))
            return false;
        if (glyph is null)
            return false;
        const key = GlyphKey(fontBase, codePoint);
        if (key in entries)
            return false;
        entries[key] = glyph;
        return true;
    }

    // Lookup: the glyph pointer, or null on a miss (including
    // non-wide code points and a null font base is allowed as
    // a key only for lookup symmetry; registration of real
    // fonts always passes a non-null base).
    void* lookupGlyph(size_t fontBase, uint codePoint)
    {
        if (!isWideCodePoint(codePoint))
            return null;
        auto p = GlyphKey(fontBase, codePoint) in entries;
        return p is null ? null : *p;
    }

    bool hasGlyph(size_t fontBase, uint codePoint)
    {
        return lookupGlyph(fontBase, codePoint) !is null;
    }

    size_t length() const
    {
        return entries.length;
    }

    // Remove every entry for one font (font reload / tests).
    void clearFont(size_t fontBase)
    {
        GlyphKey[] doomed;
        foreach (key; entries.byKey)
            if (key.fontBase == fontBase)
                doomed ~= key;
        foreach (key; doomed)
            entries.remove(key);
    }

    void clearAll()
    {
        entries = null;
    }
}

// Process-wide table used by the runtime hooks (steps 2-3).
// __gshared so the naked-asm trampolines and the D runtime
// see the same instance; access is during font load and text
// rendering on the game's main thread, as with the existing
// hooks in plugin.main_text.
private __gshared WideGlyphTable g_wideGlyphTable;

// Opt-in debug logging (item 31). Enabled only when the
// environment variable EU4DLL_GLYPH_DEBUG is exactly "1".
// It records registration and lookup of the three code points
// that distinguish the item 30 ellipsis outcome: U+623B and
// U+308B (the two glyphs of the Game Browser button's Japanese
// replacement text) and U+2026 (the ellipsis / NOT_DEF glyph).
// Every other code point stays silent, so font loading (tens of
// thousands of wide registrations) does not flood the log.
// Output goes to fd 2 via a raw write, in the same style as the
// SetText probe diagnostics; this logging is a temporary
// diagnostic for item 31/32 and is off by default.
private __gshared int g_glyphDebugState; // 0 unknown, 1 off, 2 on

bool glyphDebugEnabled()
{
    if (g_glyphDebugState == 0)
    {
        import core.stdc.stdlib : getenv;

        auto v = getenv("EU4DLL_GLYPH_DEBUG");
        g_glyphDebugState = (v !is null && v[0] == '1' && v[1] == 0) ? 2 : 1;
    }
    return g_glyphDebugState == 2;
}

bool glyphDebugInteresting(uint codePoint)
{
    return codePoint == 0x623B || codePoint == 0x308B || codePoint == 0x2026;
}

// Pure formatter for the debug lines, unit-tested below.
string formatGlyphDebugLine(string kind, size_t fontBase, uint codePoint,
        void* glyph, size_t total)
{
    import std.format : format;

    return format("[GLYPH-DEBUG] %s font=0x%x cp=0x%x glyph=0x%x total=%d\n",
            kind, fontBase, codePoint, cast(size_t) glyph, total);
}

// caller is logged as an offset from &wideGlyphLookup (item 32),
// resolvable against nm output of libeu4dll.so.
string formatGlyphDebugLineCaller(string kind, size_t fontBase, uint codePoint,
        void* glyph, size_t total, size_t caller)
{
    import std.format : format;
    return format("[GLYPH-DEBUG] %s font=0x%x cp=0x%x glyph=0x%x total=%d caller=0x%x\n",
            kind, fontBase, codePoint, cast(size_t) glyph, total, caller);
}

pragma(LDC_intrinsic, "llvm.returnaddress")
private void* llvm_returnaddress(uint level);

private void glyphDebugWrite(string line)
{
    import core.sys.posix.unistd : write;

    write(2, line.ptr, line.length);
}

extern (C) bool wideGlyphRegister(size_t fontBase, uint codePoint, void* glyph)
{
    const ok = g_wideGlyphTable.registerGlyph(fontBase, codePoint, glyph);
    if (glyphDebugEnabled() && glyphDebugInteresting(codePoint))
        glyphDebugWrite(formatGlyphDebugLine(
                ok ? "register-hit" : "register-rejected",
                fontBase, codePoint, glyph, g_wideGlyphTable.length));
    return ok;
}

// Debug log request for one lookup, handed to the preserving
// wrapper below as a single pointer argument.
private struct GlyphDebugLookupRequest
{
    string kind;
    size_t fontBase;
    uint codePoint;
    void* glyph;
    size_t total;
    size_t caller;
}

private __gshared size_t g_glyphDebugLogLookupImplAddress;

private extern (C) void glyphDebugLogLookupImpl(
        GlyphDebugLookupRequest* request)
{
    glyphDebugWrite(formatGlyphDebugLineCaller(
            request.kind, request.fontBase, request.codePoint,
            request.glyph, request.total, request.caller));
}

// XMM-preserving wrapper around glyphDebugLogLookupImpl.
//
// The plain lookup path never touches an XMM register in
// practice, and the fetch-site hooks rely on that: several of
// them keep live values in XMM registers across the call to
// wideGlyphLookup (most visibly CBitmapFont::GetWidthOfString,
// whose XMM1 is the running advance*scale total). The debug
// formatting (std.format) is under no such restraint and does
// clobber XMM registers: with EU4DLL_GLYPH_DEBUG=1 the bitmap
// accumulator turned to garbage (2.72e23) right after the
// first logged code point (width_debug_triage.md). Spilling
// the full XMM0-XMM15 around the formatting call makes the
// debug path preserve every XMM register, whichever of them a
// given call site keeps live. General-purpose registers need
// no help here: the D callee keeps the callee-saved ones, and
// call sites already protect the caller-saved ones they use,
// exactly as they do for the plain lookup.
private extern (C) void glyphDebugLogLookupPreserving(
        GlyphDebugLookupRequest* request)
{
    asm
    {
        naked;
        sub RSP, 264;
        movups [RSP + 0], XMM0;
        movups [RSP + 16], XMM1;
        movups [RSP + 32], XMM2;
        movups [RSP + 48], XMM3;
        movups [RSP + 64], XMM4;
        movups [RSP + 80], XMM5;
        movups [RSP + 96], XMM6;
        movups [RSP + 112], XMM7;
        movups [RSP + 128], XMM8;
        movups [RSP + 144], XMM9;
        movups [RSP + 160], XMM10;
        movups [RSP + 176], XMM11;
        movups [RSP + 192], XMM12;
        movups [RSP + 208], XMM13;
        movups [RSP + 224], XMM14;
        movups [RSP + 240], XMM15;
        lea R11, [g_glyphDebugLogLookupImplAddress];
        mov R11, qword ptr [R11];
        call R11;
        movups XMM0, [RSP + 0];
        movups XMM1, [RSP + 16];
        movups XMM2, [RSP + 32];
        movups XMM3, [RSP + 48];
        movups XMM4, [RSP + 64];
        movups XMM5, [RSP + 80];
        movups XMM6, [RSP + 96];
        movups XMM7, [RSP + 112];
        movups XMM8, [RSP + 128];
        movups XMM9, [RSP + 144];
        movups XMM10, [RSP + 160];
        movups XMM11, [RSP + 176];
        movups XMM12, [RSP + 192];
        movups XMM13, [RSP + 208];
        movups XMM14, [RSP + 224];
        movups XMM15, [RSP + 240];
        add RSP, 264;
        ret;
    }
}

extern (C) void* wideGlyphLookup(size_t fontBase, uint codePoint)
{
    auto glyph = g_wideGlyphTable.lookupGlyph(fontBase, codePoint);
    if (glyphDebugEnabled() && glyphDebugInteresting(codePoint))
    {
        auto request = GlyphDebugLookupRequest(
                glyph is null ? "lookup-miss" : "lookup-hit",
                fontBase, codePoint, glyph, g_wideGlyphTable.length,
                cast(size_t) llvm_returnaddress(0) - cast(size_t) &wideGlyphLookup);
        g_glyphDebugLogLookupImplAddress =
                cast(size_t) &glyphDebugLogLookupImpl;
        glyphDebugLogLookupPreserving(&request);
    }
    return glyph;
}

// Font bases that hold a given code point (item 31 diagnostic:
// lets a lookup miss be checked against every font instance
// that registered the same code point).
// Raw CString dump for the RenderToTexture sites (item 32,
// step 2): called from the site 1 / site 2 wide paths with the
// operator[] char pointer and the loop index at the START of
// the escape sequence (the hooks advance the index by 2 before
// the wide path, so they pass index-2). It reconstructs the
// string start as charPtr-index and dumps up to 48 bytes as
// hex, so the exact buffer each pass reads can be compared:
// site 1 measures the original string, site 2 draws whatever
// the line buffer holds when it produces U+2026.
string formatRawCStringLogLine(uint site, uint codePoint, uint index,
        const(ubyte)[] bytes)
{
    import std.format : format;

    string hex;
    foreach (b; bytes)
    {
        if (hex.length)
            hex ~= " ";
        hex ~= format("%02x", b);
    }
    return format("[GLYPH-DEBUG] raw site=%d cp=0x%x index=%d bytes=%s\n",
            site, codePoint, index, hex.length ? hex : "-");
}

extern (C) void wideGlyphRawLog(const(char)* charPtr, uint index,
        uint codePoint, uint site)
{
    if (!glyphDebugEnabled() || !glyphDebugInteresting(codePoint))
        return;
    if (charPtr is null || index > 4096)
        return;
    auto start = charPtr - index;
    ubyte[] buf;
    foreach (i; 0 .. 48)
    {
        const b = cast(ubyte) start[i];
        if (b == 0)
            break;
        buf ~= b;
    }
    glyphDebugWrite(formatRawCStringLogLine(site, codePoint, index, buf));
}

extern (C) size_t wideGlyphFontCountFor(uint codePoint)
{
    size_t n;
    foreach (key; g_wideGlyphTable.entries.byKey)
        if (key.codePoint == codePoint)
            n++;
    return n;
}

extern (C) void wideGlyphClearAll()
{
    g_wideGlyphTable.clearAll();
}

extern (C) size_t wideGlyphCount()
{
    return g_wideGlyphTable.length;
}

unittest
{
    WideGlyphTable table;
    auto glyphA = cast(void*) 0x1000;
    auto glyphB = cast(void*) 0x2000;
    auto glyphC = cast(void*) 0x3000;
    enum size_t font1 = 0xAAAA_0000;
    enum size_t font2 = 0xBBBB_0000;

    // Threshold gate: < 0x100 is vanilla territory.
    assert(!isWideCodePoint(0));
    assert(!isWideCodePoint(0xFF));
    assert(isWideCodePoint(0x100));
    assert(isWideCodePoint(0xFFFF));
    assert(!table.registerGlyph(font1, 0xFF, glyphA));
    assert(table.lookupGlyph(font1, 0xFF) is null);
    assert(table.length == 0);

    // Item 26 minimal-font ids: 256, 1000, 8199 must register.
    assert(table.registerGlyph(font1, 256, glyphA));
    assert(table.registerGlyph(font1, 1000, glyphB));
    assert(table.registerGlyph(font1, 8199, glyphC));
    assert(table.length == 3);
    assert(table.lookupGlyph(font1, 256) is glyphA);
    assert(table.lookupGlyph(font1, 1000) is glyphB);
    assert(table.lookupGlyph(font1, 8199) is glyphC);
    assert(table.hasGlyph(font1, 1000));
    assert(!table.hasGlyph(font1, 1001));
    assert(table.lookupGlyph(font1, 1001) is null);

    // Duplicate: second registration fails, first wins. This
    // is the predicate the duplicate-check trampoline needs.
    assert(!table.registerGlyph(font1, 1000, glyphC));
    assert(table.lookupGlyph(font1, 1000) is glyphB);
    assert(table.length == 3);

    // Null glyph is never stored (a stored null would be
    // indistinguishable from a miss at fetch sites).
    assert(!table.registerGlyph(font1, 2000, null));
    assert(table.lookupGlyph(font1, 2000) is null);

    // Per-font isolation: same code point, different font.
    assert(table.registerGlyph(font2, 1000, glyphC));
    assert(table.lookupGlyph(font2, 1000) is glyphC);
    assert(table.lookupGlyph(font1, 1000) is glyphB);
    assert(table.length == 4);

    // clearFont removes only that font; clearAll empties.
    table.clearFont(font1);
    assert(table.length == 1);
    assert(table.lookupGlyph(font1, 256) is null);
    assert(table.lookupGlyph(font2, 1000) is glyphC);
    table.clearAll();
    assert(table.length == 0);
    assert(table.lookupGlyph(font2, 1000) is null);
}

unittest
{
    // Scale check at generated-font size: 3,022 wide ids for
    // one font (item 26 count) register and resolve exactly.
    WideGlyphTable table;
    enum size_t font = 0xCCCC_0000;
    uint[] ids;
    foreach (uint cp; 0x100 .. 0x100 + 3022)
        ids ~= cp;
    foreach (i, cp; ids)
        assert(table.registerGlyph(font, cp, cast(void*)(0x10000 + i * 0x10)));
    assert(table.length == 3022);
    foreach (i, cp; ids)
        assert(table.lookupGlyph(font, cp) is cast(void*)(0x10000 + i * 0x10));
    // No duplicate among the generated range.
    assert(!table.registerGlyph(font, ids[0], cast(void*) 0x9999));
}

unittest
{
    // Global wrappers used by the later trampolines.
    wideGlyphClearAll();
    assert(wideGlyphCount() == 0);
    assert(wideGlyphRegister(0xDDDD_0000, 0x623B, cast(void*) 0x5000));
    assert(wideGlyphLookup(0xDDDD_0000, 0x623B) is cast(void*) 0x5000);
    assert(!wideGlyphRegister(0xDDDD_0000, 0x623B, cast(void*) 0x6000));
    assert(wideGlyphLookup(0xDDDD_0000, 0x41) is null);
    assert(wideGlyphCount() == 1);
    wideGlyphClearAll();
    assert(wideGlyphCount() == 0);
}

unittest
{
    // Item 31 debug helpers: only the three distinguishing code
    // points are logged, and the line carries font, code point,
    // glyph and table size.
    assert(glyphDebugInteresting(0x623B));
    assert(glyphDebugInteresting(0x308B));
    assert(glyphDebugInteresting(0x2026));
    assert(!glyphDebugInteresting(0x41));
    assert(!glyphDebugInteresting(0x100));
    assert(formatRawCStringLogLine(2, 0x2026, 0,
            [0x10, 0x26, 0x20]) ==
            "[GLYPH-DEBUG] raw site=2 cp=0x2026 index=0 bytes=10 26 20\n");
    assert(formatRawCStringLogLine(1, 0x623B, 3, []) ==
            "[GLYPH-DEBUG] raw site=1 cp=0x623b index=3 bytes=-\n");
    const line = formatGlyphDebugLine("lookup-miss", 0x1234, 0x623B, null, 42);
    assert(line == "[GLYPH-DEBUG] lookup-miss font=0x1234 cp=0x623b glyph=0x0 total=42\n");
    const cline = formatGlyphDebugLineCaller("lookup-hit", 0x1234, 0x2026, cast(void*) 0x5000, 42, 0x7000);
    assert(cline == "[GLYPH-DEBUG] lookup-hit font=0x1234 cp=0x2026 glyph=0x5000 total=42 caller=0x7000\n");
}
