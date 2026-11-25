module plugin.text_buffer_wrap;

// Entry detour on the game's CTextBuffer::GetLineCharSize
// (Linux v1.37.5) that aligns its return value down to an escape
// sequence boundary.
//
// Why: GetLineCharSize works on the CString byte length: it
// binary-searches CString::GetSize() and then adjusts one byte at
// a time (disassembly at VA 0x20d6b06), so the byte count it
// returns can fall inside a 3-byte escape sequence (lead byte
// 0x10-0x13 plus two payload bytes). Its only caller in the
// binary, CTextBuffer::GetTextAsRows (VA 0x20d6cf0, call sites
// 0x20d6e25 and 0x20d6f2d), uses the count as a byte offset: the
// row then ends mid-sequence and the remainder starts with
// payload bytes, whose measured width no longer matches the
// characters they belong to, so the following rows collapse
// (defect 3: hover dialog text that first wrapped normally and
// then stacked one character per line, or lost its middle).
//
// Measured on 2026-11-25 with EU4DLL_LINECHAR_FIX=observe: for
// the country-select tooltip strings (97 and 159 bytes) the
// original returned 67, cutting the escape sequence that starts
// at byte 66 (bytes 10 9e 62) right after its lead byte.
// Returning 66 instead made both tooltips render their full
// text with normal wrapping, verified on screen.
//
// The detour calls the original and, when the returned count
// splits an escape sequence, lowers it to that sequence's start
// offset. The aligned prefix is a prefix of the measured one, so
// its width still fits the box. Strings without escape lead
// bytes are unaffected: every byte offset is a boundary there,
// so the aligned value equals the original. GetLineCharSize is
// shared by every CTextBuffer user, not just tooltips; the
// alignment is a no-op for plain 1-byte text.
//
// Control: EU4DLL_LINECHAR_FIX selects the mode. Unset or any
// other value than the two below installs the fix (apply).
// "0" does not install the detour at all. "observe" installs it
// in a pass-through form that only logs what the alignment
// would change, for triage. In apply mode a log line is emitted
// only when a split is actually corrected. Both mirror the
// EU4DLL_LOCALIZE_ESCAPE opt-out shape.

import plugin.constant : EU4Ver;

/// True for the four escape lead bytes. The decode side in
/// plugin.main_text (ESCAPE_SEQ_1..4) treats exactly these as
/// the start of a 3-byte escape sequence.
bool isEscapeLead(ubyte b)
{
    return 0x10 <= b && b <= 0x13;
}

/// Largest byte count <= count that does not split an escape
/// sequence, scanning from the start of bytes: a lead byte
/// starts a 3-byte sequence, any other byte is one character.
/// A count at or past the end clamps to the byte length. Pure.
size_t alignToEscapeBoundary(const(ubyte)[] bytes, size_t count)
{
    if (count >= bytes.length)
        return bytes.length;
    size_t pos = 0;
    while (pos < count)
    {
        const step = isEscapeLead(bytes[pos]) ? 3 : 1;
        if (pos + step > count)
            return pos;
        pos += step;
    }
    return count;
}

/// True when the bytes contain at least one escape lead byte,
/// i.e. the text is (partly) escape-encoded. Pure.
bool containsEscapeLead(const(ubyte)[] bytes)
{
    foreach (b; bytes)
        if (isEscapeLead(b))
            return true;
    return false;
}

enum LineCharFixMode
{
    off,
    observe,
    apply,
}

/// EU4DLL_LINECHAR_FIX mode: "0" is off, "observe" is the
/// log-only pass-through, everything else (including unset)
/// applies the fix. Pure so the decision can be unit tested.
LineCharFixMode lineCharFixMode(string value)
{
    if (value == "0")
        return LineCharFixMode.off;
    if (value == "observe")
        return LineCharFixMode.observe;
    return LineCharFixMode.apply;
}

private string lineCharHexWindow(const(ubyte)[] bytes)
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

/// One diagnostic line for a GetLineCharSize call: the string
/// byte length, the original return value, the aligned value,
/// whether the original split an escape sequence, and the bytes
/// around the cut (up to 3 before and 3 from the cut). Pure.
string formatLineCharSizeLog(const(ubyte)[] bytes, int original,
        size_t aligned)
{
    import std.format : format;

    const cut = cast(size_t)(original < 0 ? 0 : original);
    const winCut = cut <= bytes.length ? cut : bytes.length;
    const start = winCut >= 3 ? winCut - 3 : 0;
    const end = winCut + 3 <= bytes.length ? winCut + 3 : bytes.length;
    const window = bytes[start .. end];
    // A count at or past the end cuts nothing, so it cannot
    // split a sequence even though clamping changed the value.
    const effective = cut <= bytes.length ? cut : bytes.length;
    return format("[DIAGNOSTIC] GetLineCharSize len=%d orig=%d aligned=%d split=%d near=%s\n",
            bytes.length, original, aligned,
            aligned != effective ? 1 : 0, lineCharHexWindow(window));
}

unittest
{
    assert(isEscapeLead(0x10) && isEscapeLead(0x13));
    assert(!isEscapeLead(0x0F) && !isEscapeLead(0x14));
    assert(!isEscapeLead(0x41));

    // Plain 1-byte text: every offset is a boundary.
    const ascii = cast(const(ubyte)[]) "hello";
    assert(alignToEscapeBoundary(ascii, 0) == 0);
    assert(alignToEscapeBoundary(ascii, 3) == 3);
    assert(alignToEscapeBoundary(ascii, 5) == 5);
    assert(alignToEscapeBoundary(ascii, 99) == 5);

    // Two escaped characters (3 bytes each) plus one ASCII byte.
    const esc = cast(const(ubyte)[])[0x10, 0xAA, 0xBB, 0x11, 0xCC, 0xDD, 0x78];
    assert(alignToEscapeBoundary(esc, 3) == 3);
    assert(alignToEscapeBoundary(esc, 4) == 3);
    assert(alignToEscapeBoundary(esc, 5) == 3);
    assert(alignToEscapeBoundary(esc, 6) == 6);
    assert(alignToEscapeBoundary(esc, 7) == 7);
    assert(alignToEscapeBoundary(esc, 100) == 7);
    // A count inside the first sequence backs off to its start.
    assert(alignToEscapeBoundary(esc, 1) == 0);
    assert(alignToEscapeBoundary(esc, 2) == 0);

    assert(containsEscapeLead(esc));
    assert(!containsEscapeLead(ascii));
    assert(!containsEscapeLead([]));

    assert(lineCharFixMode("0") == LineCharFixMode.off);
    assert(lineCharFixMode("observe") == LineCharFixMode.observe);
    assert(lineCharFixMode(null) == LineCharFixMode.apply);
    assert(lineCharFixMode("") == LineCharFixMode.apply);
    assert(lineCharFixMode("1") == LineCharFixMode.apply);

    assert(formatLineCharSizeLog(esc, 4, 3) ==
            "[DIAGNOSTIC] GetLineCharSize len=7 orig=4 aligned=3 split=1 near=aa bb 11 cc dd 78\n");
    assert(formatLineCharSizeLog(esc, 100, 7) ==
            "[DIAGNOSTIC] GetLineCharSize len=7 orig=100 aligned=7 split=0 near=cc dd 78\n");
    assert(formatLineCharSizeLog(ascii, 3, 3) ==
            "[DIAGNOSTIC] GetLineCharSize len=5 orig=3 aligned=3 split=0 near=68 65 6c 6c 6f\n");
}

version (linux)
{
    import core.sys.linux.sys.mman;
    import core.stdc.string : memcpy;
    import std.exception : enforce;
    import std.format : format;
    import std.logger;
    import std.process : environment;
    import plugin.byte_pattern;
    import plugin.patcher.patcher : makeJmpRel, patch_memory;

    // Complete instructions overwritten at the entry: push rbp,
    // push r15, push r14, push r13, push r12, push rbx
    // (1+2+2+2+2+1). The patch is a 5-byte relative jump plus
    // 5 NOPs, the reload_trace / localize form: the entry
    // trampoline is allocated within rel32 range of the target
    // and checked with fitsRel32.
    private enum size_t CopiedLength = 10;
    private enum size_t CallPatchLength = 5;
    private enum int MaxCStringBytes = 1 << 20;
    private enum size_t MaxLineCharLogLines = 500;

    // CString layout, proven from the game binary's own code:
    // CString::GetSize reads the int at +8 (VA 0x254c3ee) and
    // GetTextAsRows passes the pointer at +0 as the char data.
    private struct CStringView
    {
        const(char)* data;
        int length;
    }

    private alias GetLineCharSizeFn = extern(C) int function(
            void* self, const(void)* cstring);

    private __gshared GetLineCharSizeFn getLineCharSizeOriginal;
    private __gshared LineCharFixMode g_lineCharMode;
    private __gshared bool lineCharHookInstalled;
    private __gshared size_t lineCharLogLines;

    private bool fitsRel32(void* fromAddress, void* toAddress)
    {
        auto distance = cast(long) toAddress
            - (cast(long) fromAddress + cast(long) CallPatchLength);
        return distance >= -2147483648L && distance <= 2147483647L;
    }

    private void* makeEntryTrampoline(void* nearAddress, void* callback)
    {
        auto pageSize = 4096UL;
        auto hint = cast(void*)(cast(size_t) nearAddress & ~(pageSize - 1));
        auto memory = mmap(hint, 16, PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
        enforce(memory !is MAP_FAILED,
            "mmap for GetLineCharSize entry trampoline failed");

        auto code = cast(ubyte*) memory;
        auto target = cast(size_t) callback;
        code[0 .. 10] = [0x48, 0xb8,
            cast(ubyte)(target >> 0), cast(ubyte)(target >> 8),
            cast(ubyte)(target >> 16), cast(ubyte)(target >> 24),
            cast(ubyte)(target >> 32), cast(ubyte)(target >> 40),
            cast(ubyte)(target >> 48), cast(ubyte)(target >> 56)];
        code[10 .. 12] = [0xff, 0xe0];
        return memory;
    }

    private void* makeOriginalTrampoline(void* target)
    {
        auto memory = mmap(null, 32, PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
        enforce(memory !is MAP_FAILED,
            "mmap for GetLineCharSize original trampoline failed");

        auto code = cast(ubyte*) memory;
        memcpy(code, target, CopiedLength);
        auto resume = cast(size_t) target + CopiedLength;
        code[CopiedLength .. CopiedLength + 10] = [0x48, 0xb8,
            cast(ubyte)(resume >> 0), cast(ubyte)(resume >> 8),
            cast(ubyte)(resume >> 16), cast(ubyte)(resume >> 24),
            cast(ubyte)(resume >> 32), cast(ubyte)(resume >> 40),
            cast(ubyte)(resume >> 48), cast(ubyte)(resume >> 56)];
        code[CopiedLength + 10 .. CopiedLength + 12] = [0xff, 0xe0];
        return memory;
    }

    private bool readCString(const(void)* cstring, out const(ubyte)[] bytes)
    {
        bytes = null;
        if (cstring is null)
            return false;
        auto view = cast(const(CStringView)*) cstring;
        if (view.length == 0)
            return true;
        if (view.data is null || view.length < 0
                || view.length > MaxCStringBytes)
            return false;
        bytes = cast(const(ubyte)[]) view.data[0 .. view.length];
        return true;
    }

    private void logLineChar(const(ubyte)[] bytes, int original,
            size_t aligned)
    {
        if (lineCharLogLines >= MaxLineCharLogLines)
            return;
        lineCharLogLines++;
        log(LogLevel.info, formatLineCharSizeLog(bytes, original, aligned));
    }

    private extern(C) int getLineCharSizeCallback(void* self,
            const(void)* cstring)
    {
        const original = getLineCharSizeOriginal(self, cstring);
        if (original <= 0)
            return original;
        const(ubyte)[] bytes;
        if (!readCString(cstring, bytes) || bytes.length == 0)
            return original;
        const aligned = alignToEscapeBoundary(bytes, cast(size_t) original);
        if (g_lineCharMode == LineCharFixMode.observe)
        {
            if (containsEscapeLead(bytes))
                logLineChar(bytes, original, aligned);
            return original;
        }
        if (aligned == cast(size_t) original)
            return original;
        logLineChar(bytes, original, aligned);
        // Never return 0 for a count the original found room
        // for: GetTextAsRows advances by the returned count, so
        // 0 would loop on the same text forever. Keep the
        // original (splitting) value for that degenerate case.
        if (aligned == 0)
            return original;
        return cast(int) aligned;
    }

    void initTextBufferWrap(EU4Ver eu4Version)
    {
        if (eu4Version != EU4Ver.v1_37_5)
            return;
        const mode = lineCharFixMode(environment.get("EU4DLL_LINECHAR_FIX"));
        if (mode == LineCharFixMode.off)
        {
            log(LogLevel.info,
                "[DIAGNOSTIC] EU4DLL_LINECHAR_FIX=0; GetLineCharSize detour not installed");
            return;
        }
        g_lineCharMode = mode;

        auto pattern = BytePattern.tempInstance();
        // CTextBuffer::GetLineCharSize prologue and the font load
        // that follows it; unique in the v1.37.5 binary (verified
        // against the file: one hit at VA 0x20d6b06).
        pattern.findPattern("55 41 57 41 56 41 55 41 54 53 48 83 EC 18 48 89 F3 49 89 FF 48 8B BF 98 00 00 00");
        if (pattern.count() != 1)
        {
            log(LogLevel.error, format(
                "[DIAGNOSTIC] GetLineCharSize target match count=%s",
                pattern.count()));
            return;
        }
        auto target = cast(void*) pattern.getFirst().address();
        getLineCharSizeOriginal = cast(GetLineCharSizeFn)
            makeOriginalTrampoline(target);

        if (lineCharHookInstalled)
            return;

        auto entry = makeEntryTrampoline(target,
            cast(void*) &getLineCharSizeCallback);
        if (!fitsRel32(target, entry))
        {
            log(LogLevel.error,
                "[DIAGNOSTIC] GetLineCharSize entry exceeds rel32");
            return;
        }
        patch_memory(target, makeJmpRel(target, entry)
            ~ cast(ubyte[])[0x90, 0x90, 0x90, 0x90, 0x90]);
        lineCharHookInstalled = true;
        log(LogLevel.info, format(
            "[DIAGNOSTIC] GetLineCharSize detour installed target=0x%x mode=%s",
            cast(size_t) target,
            mode == LineCharFixMode.observe ? "observe" : "apply"));
    }
}
else
{
    void initTextBufferWrap(EU4Ver eu4Version) {}
}
