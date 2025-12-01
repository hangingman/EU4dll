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

    bool hasSize(size_t expected, string desc)
    {
        return true;
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
                ptrdiff_t index = std.algorithm.searching.countUntil!((a, b)
                                              {
                                                  return (a & b.mask) == (b.pattern & b.mask);
                                              })(section, pattern);

                if (index != -1)
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
