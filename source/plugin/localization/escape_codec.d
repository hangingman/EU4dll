module plugin.localization.escape_codec;

// UTF-8 -> EU4 escaped-text encoder (item 10), plus a decode test
// double used only by the unittests below.
//
// The conversion table is a port of upstream matanki-saito/EU4dll
// (develop branch) Plugin64/escape_tool.cpp:
//   convertWideTextToEscapedText  (encode)
//   convertEscapedTextToWideText  (decode, mirrored by decodeEscaped)
//   UCS2ToCP1252 / CP1252ToUCS2   (single-byte special cases)
// Last upstream change to that file: commit a0fedb2 (2024-08-24).
// The shift adjustments match this repo's decode side in
// plugin.main_text (ESCAPE_SEQ_1..4 = 0x10..0x13, SHIFT_2 = 0x0E,
// SHIFT_3 = 0x900, SHIFT_4 = 0x8F2, NO_FONT = 0x98F,
// NOT_DEF = 0x2026). See memory-bank/details/escape_codec.md for the
// full derivation and the two documented deviations from upstream.
//
// This module is pure: it does not touch the game, the SetText hook,
// or any file. Wiring into the SetText hook was done in item 20
// (settext_hook.d converts non-ASCII replacements at load time);
// see memory-bank/details/settext_escape_wiring.md.

import std.utf : decode, UTFException;

// Bytes that must not appear verbatim in the stored two-byte word:
// upstream decides the escape byte from whether the high / low byte
// of the code point is in this set. The set is copied verbatim from
// escape_tool.cpp (both switch statements use the same list).
private bool isProblematicByte(ubyte b)
{
    switch (b)
    {
    case 0xA4, 0xA3, 0xA7, 0x24, 0x5B, 0x00, 0x5C, 0x20, 0x0D, 0x0A,
        0x22, 0x7B, 0x7D, 0x40, 0x80, 0x7E, 0x2F, 0x5F, 0xBD, 0x3B,
        0x5D, 0x3D, 0x23, 0x3F, 0x3A, 0x3C, 0x3E, 0x2A, 0x7C:
        return true;
    default:
        return false;
    }
}

// UCS2ToCP1252 from escape_tool.cpp: code points that the game
// represents as a single CP1252 byte. Returns the code point itself
// when it has no single-byte representation.
private dchar ucs2ToCp1252(dchar cp)
{
    switch (cp)
    {
    case 0x20AC: return 0x80;
    case 0x201A: return 0x82;
    case 0x0192: return 0x83;
    case 0x201E: return 0x84;
    case 0x2026: return 0x85;
    case 0x2020: return 0x86;
    case 0x2021: return 0x87;
    case 0x02C6: return 0x88;
    case 0x2030: return 0x89;
    case 0x0160: return 0x8A;
    case 0x2039: return 0x8B;
    case 0x0152: return 0x8C;
    case 0x017D: return 0x8E;
    case 0x2018: return 0x91;
    case 0x2019: return 0x92;
    case 0x201C: return 0x93;
    case 0x201D: return 0x94;
    case 0x2022: return 0x95;
    case 0x2013: return 0x96;
    case 0x2014: return 0x97;
    case 0x02DC: return 0x98;
    case 0x2122: return 0x99;
    case 0x0161: return 0x9A;
    case 0x203A: return 0x9B;
    case 0x0153: return 0x9C;
    case 0x017E: return 0x9E;
    case 0x0178: return 0x9F;
    default: return cp;
    }
}

// CP1252ToUCS2 from escape_tool.cpp (inverse of the table above).
private dchar cp1252ToUcs2(ubyte b)
{
    switch (b)
    {
    case 0x80: return 0x20AC;
    case 0x82: return 0x201A;
    case 0x83: return 0x0192;
    case 0x84: return 0x201E;
    case 0x85: return 0x2026;
    case 0x86: return 0x2020;
    case 0x87: return 0x2021;
    case 0x88: return 0x02C6;
    case 0x89: return 0x2030;
    case 0x8A: return 0x0160;
    case 0x8B: return 0x2039;
    case 0x8C: return 0x0152;
    case 0x8E: return 0x017D;
    case 0x91: return 0x2018;
    case 0x92: return 0x2019;
    case 0x93: return 0x201C;
    case 0x94: return 0x201D;
    case 0x95: return 0x2022;
    case 0x96: return 0x2013;
    case 0x97: return 0x2014;
    case 0x98: return 0x02DC;
    case 0x99: return 0x2122;
    case 0x9A: return 0x0161;
    case 0x9B: return 0x203A;
    case 0x9C: return 0x0153;
    case 0x9E: return 0x017E;
    case 0x9F: return 0x0178;
    default: return b;
    }
}

// Encode one code point. Returns false when the code point cannot
// be represented: upstream works on 16-bit wchar_t, so anything
// above the BMP is out of range.
bool encodeCodePoint(dchar cp0, out ubyte[] escaped)
{
    escaped = null;
    if (cp0 > 0xFFFF)
        return false;

    // Single-byte special cases (CP1252). Deviation from upstream,
    // recorded in details/escape_codec.md: upstream writes
    // (BYTE)cp (the truncated original), which its own decoder does
    // not invert; we write the mapped byte returned by
    // UCS2ToCP1252, which CP1252ToUCS2 inverts exactly.
    const mapped = ucs2ToCp1252(cp0);
    if (mapped != cp0)
    {
        escaped = [cast(ubyte) mapped];
        return true;
    }

    dchar cp = cp0;
    // Upstream shifts this band out of the NO_FONT dead zone
    // (0x100 < cp < 0x98F decodes to NOT_DEF). The decode side does
    // not shift back, so this band does not round-trip; see the
    // fixed-vector unittest and the details file.
    if (cp > 0x100 && cp < 0xA00)
        cp += 0xE000;

    ubyte high = cast(ubyte)((cp >> 8) & 0xFF);
    ubyte low = cast(ubyte)(cp & 0xFF);

    if (high == 0)
    {
        escaped = [cast(ubyte) cp];
        return true;
    }

    ubyte escapeChr = 0x10;
    if (isProblematicByte(high))
        escapeChr += 2;
    if (isProblematicByte(low))
        escapeChr += 1;

    switch (escapeChr)
    {
    case 0x11:
        low = cast(ubyte)(low + 14);
        break;
    case 0x12:
        high = cast(ubyte)(high - 9);
        break;
    case 0x13:
        low = cast(ubyte)(low + 14);
        high = cast(ubyte)(high - 9);
        break;
    default:
        break;
    }

    escaped = [escapeChr, low, high];
    return true;
}

// Encode a whole UTF-8 string. Returns false (and clears the
// output) on invalid UTF-8 or an unrepresentable code point; a
// partial encoding is never returned.
bool encodeUtf8ToEscaped(const(char)[] text, out ubyte[] escaped)
{
    escaped = null;
    ubyte[] result;
    size_t index = 0;
    while (index < text.length)
    {
        dchar cp;
        try
        {
            cp = decode(text, index);
        }
        catch (UTFException)
        {
            return false;
        }
        ubyte[] piece;
        if (!encodeCodePoint(cp, piece))
            return false;
        result ~= piece;
    }
    escaped = result;
    return true;
}

// Decode test double: a port of upstream
// convertEscapedTextToWideText. This mirrors the decode rules the
// game-side hooks apply (same escape bytes and shift adjustments as
// plugin.main_text); it exists so unittests can check the round
// trip without the game. It is not used at runtime.
// Returns false on a truncated escape sequence.
bool decodeEscaped(const(ubyte)[] escaped, out dchar[] codePoints)
{
    codePoints = null;
    dchar[] result;
    size_t index = 0;
    while (index < escaped.length)
    {
        const b = escaped[index++];
        uint sp;
        if (b >= 0x10 && b <= 0x13)
        {
            if (index + 2 > escaped.length)
                return false;
            const low = escaped[index++];
            const high = escaped[index++];
            sp = (cast(uint) high << 8) + low;
            switch (b)
            {
            case 0x11:
                sp -= 0x0E;
                break;
            case 0x12:
                sp += 0x900;
                break;
            case 0x13:
                sp += 0x8F2;
                break;
            default:
                break;
            }
            if (sp > 0xFFFF || (sp < 0x98F && sp > 0x100))
                sp = 0x2026;
        }
        else
        {
            sp = cp1252ToUcs2(b);
        }
        result ~= cast(dchar) sp;
    }
    codePoints = result;
    return true;
}

unittest
{
    ubyte[] enc;
    dchar[] dec;

    // ASCII passes through unescaped.
    assert(encodeUtf8ToEscaped("Back", enc));
    assert(enc == cast(ubyte[]) "Back");
    assert(decodeEscaped(enc, dec) && dec == "Back"d);

    // Fixed vectors, one per escape band. Byte order after the
    // escape byte is low, high (little-endian stored word).
    // U+623B (戻): low 0x3B is problematic -> 0x11, low += 0x0E.
    // U+308B (る): neither byte problematic -> 0x10.
    assert(encodeUtf8ToEscaped("戻る", enc));
    assert(enc == cast(ubyte[])[0x11, 0x49, 0x62, 0x10, 0x8B, 0x30]);
    assert(decodeEscaped(enc, dec) && dec == "戻る"d);

    // U+63A5 (接): -> 0x10. U+7D9A (続): high 0x7D is problematic
    // -> 0x12, high -= 9. (CONNECT_TO_IP value from item 8.)
    assert(encodeUtf8ToEscaped("ID接続", enc));
    assert(enc == (cast(ubyte[]) "ID") ~ cast(ubyte[])[0x10, 0xA5, 0x63, 0x12, 0x9A, 0x74]);
    assert(decodeEscaped(enc, dec) && dec == "ID接続"d);

    // U+5C3B (尻): high 0x5C and low 0x3B both problematic
    // -> 0x13, low += 0x0E and high -= 9.
    assert(encodeUtf8ToEscaped("尻", enc));
    assert(enc == cast(ubyte[])[0x13, 0x49, 0x53]);
    assert(decodeEscaped(enc, dec) && dec == "尻"d);

    // Kana / prolonged sound mark (MENU_BAR_LOAD_GAME value).
    assert(encodeUtf8ToEscaped("ロード", enc));
    assert(enc == cast(ubyte[])[0x10, 0xED, 0x30, 0x10, 0xFC, 0x30, 0x10, 0xC9, 0x30]);
    assert(decodeEscaped(enc, dec) && dec == "ロード"d);

    // Round trips over representable ranges: ASCII, kana, kanji,
    // and mixed text (translation values from item 8).
    foreach (sample; ["Back", "戻る", "ID接続", "ロード",
            "A戻B", "戦争と平和", "カトリック教会", "§1"])
    {
        // NOTE: "§1" is U+00A7 + '1'; U+00A7 is single-byte range.
        assert(encodeUtf8ToEscaped(sample, enc), sample);
        assert(decodeEscaped(enc, dec), sample);
        import std.conv : to;

        assert(dec == to!dstring(sample), sample);
    }

    // CP1252 special case: U+20AC (euro sign) is one byte 0x80
    // and round-trips through CP1252ToUCS2.
    assert(encodeUtf8ToEscaped("€", enc));
    assert(enc == cast(ubyte[])[0x80]);
    assert(decodeEscaped(enc, dec) && dec == "€"d);

    // The 0x100 < cp < 0xA00 band is shifted by +0xE000 upstream
    // and does NOT round-trip: U+0101 encodes as U+E101 and the
    // decoder returns the shifted value. Fixed vector only.
    assert(encodeUtf8ToEscaped("ā", enc)); // U+0101
    assert(enc == cast(ubyte[])[0x10, 0x01, 0xE1]);
    assert(decodeEscaped(enc, dec) && dec == [cast(dchar) 0xE101]);

    // Unrepresentable inputs fail as a whole, with no output.
    assert(!encodeUtf8ToEscaped("😀", enc) && enc is null); // above BMP
    assert(!encodeUtf8ToEscaped(cast(string) "\xE6\x88", enc) && enc is null); // truncated UTF-8
    assert(!decodeEscaped([0x10, 0x8B], dec)); // truncated escape

    // Escaped length accounting: 3 bytes per escaped character,
    // which is what the CString capacity check must use.
    assert(encodeUtf8ToEscaped("戻る", enc) && enc.length == 6);
}
