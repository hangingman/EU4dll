module plugin.byte_pattern;

import core.stdc.stdint;
import core.sys.posix.dlfcn;
import elf;
import plugin.memory_pointer;
import plugin.singleton;
import scriptlike.core;
import scriptlike.file.extras : existsAsFile;
import scriptlike.file.wrappers : readText;
import scriptlike.path.extras : Path;
import std.conv;
import std.container : Array, SList;
import std.file : thisExePath;
import std.stdio : File; // Fileのみをインポート
import core.stdc.stdio : SEEK_SET;
import std.typecons;
import std.array : replicate;
import std.format;
import std.range;
import std.algorithm;
import core.stdc.stdlib;
import std.algorithm.searching : BoyerMooreFinder;
import cerealed;
import std.mmfile;
import std.logger; // std.loggerのために追加

alias SectionRange = Tuple!(size_t, "fileOffset", size_t, "size", uintptr_t, "virtualAddress");
alias Pat = Tuple!(uint8_t, "pattern", uint8_t, "mask");
alias Patterns = Pat[];
alias Bytes = ubyte[];

class BytePattern
{
    mixin singleton;

    Bytes[string] _contents;
    Array!(SectionRange) _ranges;
    Patterns _maskedPattern;
    Array!(MemoryPointer) _results;
    string _literal;
    ptrdiff_t[256] _bmbc;

    // 仮想アドレスをファイルオフセットに変換するヘルパー関数
    size_t virtualAddressToFileOffset(uintptr_t virtualAddress)
    {
        foreach (range; _ranges) {
            if (virtualAddress >= range.virtualAddress && virtualAddress < range.virtualAddress + range.size) {
                size_t offsetInSection = virtualAddress - range.virtualAddress;
                return range.fileOffset + offsetInSection;
            }
        }
        std.logger.error(format("Virtual address 0x%x not found in any section ranges.", virtualAddress));
        throw new Exception(format("Virtual address 0x%x not found in any section ranges.", virtualAddress));
    }

    static typeof(this) tempInstance()
    {
        return BytePattern.opCall();
    }

    this()
    {
        setModule();
    }

    static void clearContentsCache()
    {
        BytePattern.opCall()._contents.clear();
    }

    uint8_t digitToValue(uint8_t ch)
    {
        if ('0' <= ch && ch <= '9')
            {
                return cast(uint8_t) (ch - '0');
            }
        else if ('A' <= ch && ch <= 'F')
            {
                return cast(uint8_t) (ch - 'A' + 10);
            }
        else if ('a' <= ch && ch <= 'f')
            {
                return cast(uint8_t) (ch - 'a' + 10);
            }

        std.logger.error("Could not parse pattern: Invalid hex digit.");
        throw new Exception("Could not parse pattern.");
    }

    string hexToUTF8(string hex)
    {
        return hex.replace(" ", "")
            .replace("?", "2A")
            .chunks(2)
            .map!(digits => cast(char) digits.to!ubyte(16))
            .to!string;
    }

    Bytes binToRange(string binPath = thisExePath())
    {
        if (auto content = binPath in _contents)
            {
                return *content;
            }
        auto f = File(binPath, "r");
        scope(exit) f.close();
        size_t size = f.size;
        ubyte[] content = new ubyte[size];
        f.rawRead(content);
        _contents[binPath] = content;
        return _contents[binPath];
    }

    Pat parseSubPattern(string sub)
    {
        Pat result;

        if (sub.length == 1)
            {
                if (sub[0] == '?')
                    {
                        result.pattern = 0;
                        result.mask = 0;
                    }
                else
                    {
                        result.pattern = digitToValue(sub[0]);
                        result.mask = 0xFF;
                    }
            }
        else if (sub.length == 2)
            {
                if (sub[0] == '?' && sub[1] == '?')
                    {
                        result.pattern = 0;
                        result.mask = 0;
                    }
                else if (sub[0] == '?')
                    {
                        result.pattern = digitToValue(sub[1]);
                        result.mask = 0xF;
                    }
                else if (sub[1] == '?')
                    {
                        result.pattern = cast(uint8_t) (digitToValue(sub[0]) << 4);
                        result.mask = 0xF0;
                    }
                else
                    {
                        result.pattern = cast(uint8_t) ((digitToValue(sub[0]) << 4) | digitToValue(sub[1]));
                        result.mask = 0xFF;
                    }
            }
        else
            {
                std.logger.error(format("Could not parse pattern: Invalid sub-pattern length %s.", sub));
                throw new Exception("Could not parse pattern.");
            }

        return result;
    }

    void transformPattern(string literal)
    {
        clear();
        _literal = literal;

        if (literal.empty())
            {
                return;
            }

        Array!(string) subPatterns = _literal.split(" ");

        try
            {
                foreach (sub; subPatterns)
                    {
                        auto pat = parseSubPattern(sub);
                        _maskedPattern ~= pat;
                    }
            }
        catch (Exception e)
            {
                std.logger.error(format("Error transforming pattern '%s': %s", literal, e.msg));
                this.clear();
            }
    }

    // elf-dの実装でも、内部的にはファイルをMmFileとして扱っている
    // https://github.com/yazd/elf-d/blob/master/source/elf/package.d
    void getModuleRanges(MmFile mmf)
    {
        ELF elf = ELF.fromFile(mmf);
        setModuleRanges(elf);
    }

    void getModuleRanges(string binPath = thisExePath())
    {
        ELF elf = ELF.fromFile(binPath);
        setModuleRanges(elf);
    }

    void setModuleRanges(ELF elf)
    {
        // 実行ファイルのすべてのセクションテーブルを取得し、その開始アドレス終了アドレスを
        // _ranges に格納する(ELFでの実装のみ対応)
        _ranges.clear();

        foreach (section; elf.sections) {
            if (section.name == ".text" || section.name == ".rodata")
            {
                SectionRange range;
                range.fileOffset = section.offset;
                range.size = section.size;
                range.virtualAddress = section.address;
                _ranges.insertBack(range);
            }
        }
    }

    void clear()
    {
        _literal = "";
        _maskedPattern = [];
        _results.clear();
    }

    size_t count()
    {
        return _results.length;
    }

    // True only when the last search found exactly `expected` matches.
    // Every injector gates on this before touching getFirst()/getSecond(),
    // so a pattern that is missing or ambiguous must fail here instead of
    // patching an arbitrary first hit. This was a stub returning true
    // unconditionally until the Linux injection work (item 14); the real
    // check also needs findIndexes() to record every hit, not just the
    // first hit per section.
    bool hasSize(size_t expected, string desc)
    {
        if (count() == expected)
            return true;
        std.logger.error(format(
            "BytePattern match count mismatch for '%s': expected %d, found %d (pattern: %s)",
            desc, expected, count(), _literal));
        return false;
    }

    // True when the last search found at least `expected` matches.
    // For callers that legitimately use only the first hit of a pattern
    // that occurs several times (e.g. the EU4 version string, which
    // occurs 4 times in the v1.37.5 binary): the count is still checked
    // and logged here, instead of being silently assumed to be 1.
    bool hasAtLeast(size_t expected, string desc)
    {
        if (count() >= expected)
            return true;
        std.logger.error(format(
            "BytePattern match count too small for '%s': expected at least %d, found %d (pattern: %s)",
            desc, expected, count(), _literal));
        return false;
    }

    // Pure matcher used by findIndexes(): every offset in `section`
    // whose bytes match `pattern` under its masks, in order, including
    // overlapping matches. Kept separate so the counting behaviour can
    // be unit tested without a module image.
    static size_t[] findAllMatchOffsets(in ubyte[] section, in Patterns pattern)
    {
        size_t[] offsets;
        if (pattern.length == 0 || section.length < pattern.length)
            return offsets;
        foreach (start; 0 .. section.length - pattern.length + 1)
        {
            bool matched = true;
            foreach (i, pat; pattern)
            {
                if ((section[start + i] & pat.mask) != (pat.pattern & pat.mask))
                {
                    matched = false;
                    break;
                }
            }
            if (matched)
                offsets ~= start;
        }
        return offsets;
    }

    bool empty()
    {
        return _results.empty();
    }

    void findIndexes(string binPath = thisExePath())
    {
        findIndexes(binToRange(binPath));
    }

    void findIndexes(in ubyte[] contents)
    {
        const Patterns pattern = this._maskedPattern.dup;
        const size_t patternLen = this._maskedPattern.length;
        this._results.clear();

        if (patternLen == 0)
            {
                return;
            }

        foreach (range ; this._ranges)
            {
                debug {
                    std.logger.info(format("module size: %d", contents.length));
                    std.logger.info(format("[%x .. %x]", range.fileOffset, range.fileOffset + range.size));
                    std.logger.info(format("pattern: %s", pattern.map!(d => std.conv.to!string(d.pattern, 16) ).join(" ")));
                    std.logger.info(format("mask: %s", pattern.map!(d => std.conv.to!string(d.mask, 16) ).join(" ")));
                }

                auto section = contents[range.fileOffset .. range.fileOffset + range.size];
                // Record every hit, not just the first per section:
                // hasSize() uniqueness checks are meaningless otherwise
                // (a pattern occurring twice in .text would report 1).
                foreach (index; findAllMatchOffsets(section, pattern))
                    {
                        MemoryPointer m = new MemoryPointer(range.virtualAddress + index, patternLen);
                        this._results.insertBack(m);
                        debug {
                            std.logger.info(format("Found on: 0x%x", range.virtualAddress + index));
                            std.logger.info(format("Bytes: %s", section[index .. index + patternLen].map!(d => std.conv.to!string(d, 16) ).join(" ")));
                        }
                    }
            }
    }

    BytePattern search()
    {
        findIndexes();
        return this;
    }

    BytePattern findPattern(string patternLiteral)
    {
        std.logger.info(format("findPattern str: %s, hex: %s", hexToUTF8(patternLiteral), patternLiteral));
        this.setPattern(patternLiteral).search();
        return this;
    }

    T found(T)()
    {
        auto m = getFirst();
        size_t fileOffset = virtualAddressToFileOffset(m.address());
        const ubyte[] content = binToRange()[fileOffset .. fileOffset + m.byteLength];
        debug {
            std.logger.info("-- found --");
            std.logger.info(format("from 0x%x (virtual)", m.address()));
            std.logger.info(format("from 0x%x (file offset)", fileOffset));
            std.logger.info(format("to 0x%x (virtual)", m.address(m.byteLength)));
            std.logger.info(format("to 0x%x (file offset)", fileOffset + m.byteLength));
            std.logger.info(format("Content: %s", content.map!(d => std.conv.to!string(d, 16) ).join(" ")));
        }
        T ans = cerealed.decerealise!T(content);
        return ans;
    }

    T findPattern(T)(string patternLiteral)
    {
        findPattern(patternLiteral);
        auto m = getFirst();
        return found!T();
    }

    BytePattern setPattern(string patternLiteral)
    {
        transformPattern(patternLiteral);
        return this;
    }

    BytePattern setModule(string binPath = thisExePath())
    {
        this.getModuleRanges(binPath);
        return this;
    }

    BytePattern setMmFile(MmFile mmf)
    {
        this.getModuleRanges(mmf);
        return this;
    }

    // `getFirst`メソッドを追加
    MemoryPointer getFirst()
    {
        if (_results.empty)
        {
            std.logger.error("No pattern found for getFirst().");
            throw new Exception("No pattern found for getFirst().");
        }
        return _results[0];
    }

    // `getSecond`メソッドを追加
    MemoryPointer getSecond()
    {
        if (_results.length < 2)
        {
            std.logger.error("No second pattern found for getSecond().");
            throw new Exception("No second pattern found for getSecond().");
        }
        return _results[1];
    }

    // `get(int index)`メソッドを追加
    MemoryPointer get(int index)
    {
        if (index >= _results.length || index < 0)
        {
            std.logger.error(format("Index %d out of bounds for get().", index));
            throw new Exception(format("Index %d out of bounds for get().", index));
        }
        return _results[index];
    }
}

unittest
{
    // findAllMatchOffsets counts every hit, including a second hit in
    // the same section (the old findIndexes kept only the first one).
    Patterns pat = [Pat(0xAA, 0xFF), Pat(0xBB, 0xFF)];
    ubyte[] data = [0x00, 0xAA, 0xBB, 0xAA, 0xBB, 0xAA, 0x00];
    assert(BytePattern.findAllMatchOffsets(data, pat) == [1, 3]);
    // Masked (wildcard) bytes match any value in that position.
    Patterns masked = [Pat(0xAA, 0xFF), Pat(0x00, 0x00)];
    assert(BytePattern.findAllMatchOffsets(data, masked) == [1, 3, 5]);
    // No hit, empty pattern and a pattern longer than the data are empty.
    assert(BytePattern.findAllMatchOffsets(data, [Pat(0xFF, 0xFF)]).length == 0);
    assert(BytePattern.findAllMatchOffsets(data, []).length == 0);
    assert(BytePattern.findAllMatchOffsets([0xAA], pat).length == 0);
}
