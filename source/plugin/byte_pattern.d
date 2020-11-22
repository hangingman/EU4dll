module plugin.byte_pattern;


import core.stdc.stdint;
import core.sys.posix.dlfcn;
import elf;
import freck.streams.filestream;
import freck.streams.stream;
import plugin.memory_pointer;
import plugin.singleton;
import scriptlike.core;
import scriptlike.file.extras : existsAsFile;
import scriptlike.path.extras : Path;
import std.conv;
import std.container : Array;
import std.file : thisExePath;
import std.stdio;
import std.typecons;
import std.array : replicate;
import std.format;
import std.range;
import std.algorithm;


alias Range = Tuple!(uintptr_t, "first", uintptr_t, "second");
alias Pat = Tuple!(uint8_t, "first", uint8_t, "second");


class BytePattern
{
    // シングルトンパターン
    mixin singleton;
    
    Array!(Range) _ranges;
    Array!(uint8_t) _pattern;
    Array!(uint8_t) _mask;
    Array!(MemoryPointer) _results;
    string _literal;
    ptrdiff_t[256] _bmbc;
    static Stream _stream = null;
    const string sep = replicate("-", 80);
    
    static typeof(this) tempInstance()
    {
        return BytePattern();
    };

    this()
    {
        setModule();
    };
    
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
        
        throw new Exception("Could not parse pattern.");
    };

    string hexToUTF8(string hex)
    {
        return hex.replace(" ", "")
            .replace("?", "2A")
            .chunks(2)
            .map!(digits => cast(char) digits.to!ubyte(16))
            .to!string;
    }
    
    Pat parseSubPattern(string sub)
    {
        // パターンマッチを使いたいが、D言語にはない
        Pat result;
        
        if (sub.length == 1)
            {
                if (sub[0] == '?')
                    {
                        result.first = 0;
                        result.second = 0;
                    }
                else
                    {
                        result.first = digitToValue(sub[0]);
                        result.second = 0xFF;
                    }
            }
        else if (sub.length == 2)
            {
                if (sub[0] == '?' && sub[1] == '?')
                    {
                        result.first = 0;
                        result.second = 0;
                    }
                else if (sub[0] == '?')
                    {
                        result.first = digitToValue(sub[1]);
                        result.second = 0xF;
                    }
                else if (sub[1] == '?')
                    {
                        result.first = cast(uint8_t) (digitToValue(sub[0]) << 4);
                        result.second = 0xF0;
                    }
                else
                    {
                        result.first = cast(uint8_t) ((digitToValue(sub[0]) << 4) | digitToValue(sub[1]));
                        result.second = 0xFF;
                    }
            }
        else
            {
                throw new Exception("Could not parse pattern.");
            }
        
        return result;
    };

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
                        _pattern ~= pat.first;
                        _mask ~= pat.second;
                    }
            }
        catch (Exception e)
            {
                this.clear();
            }
    };

    void getModuleRanges(MemoryPointer mod, string binPath = thisExePath())
    {
        // DLLのすべてのセクションテーブルを取得し、その開始アドレス終了アドレス
        // を _ranges に格納するPE/COFFの場合とELFでの実装が必要
        _ranges.clear();
        
        version(Windows)
            {
                
            }
        else
            {
                ELF elf = ELF.fromFile(binPath);

                // ELF sections
                foreach (section; elf.sections) {
                    Range range;
                    auto secSize = section.size;
                    range.first = section.address;

                    if (section.name == ".text" || section.name == ".rodata")
                        {
                            // .text, .rodataのセクションの範囲を取得する
                            // writeln("  Section (", section.name, ")");
                            // writefln("    type: %s", section.type);
                            // writefln("    address: 0x%x", section.address);
                            // writefln("    offset: 0x%x", section.offset);
                            // writefln("    flags: 0x%08b", section.flags);
                            // writefln("    size: %s bytes", section.size);
                            // writefln("    entry size: %s bytes", section.entrySize);
                            // writeln();

                            range.second = range.first + secSize;
                            _ranges.insert(range);
                        }
                }
            }
    };

    void clear()
    {
        _literal = "";
        _pattern.clear();
        _mask.clear();
        _results.clear();
    }
    
    size_t count()
    {
        return _results.length;
    }
    
    bool hasSize(size_t expected, string desc)
    {
        return true;
    };
    
    bool empty()
    {
        return _results.empty();
    };
    
    void bmPreprocess()
    {
    };

    void bmSearch()
    {
        const Array!ubyte pbytes = this._pattern.dup;
        const Array!ubyte pmask = this._mask.dup;
        size_t patternLen = this._pattern.length();
        debugOutput(mixin(interp!"bmSearch patternLen: ${patternLen}"));

        this._results.clear();

        if (patternLen == 0)
            {
                return;
            }

        foreach (range ; this._ranges)
            {
                uint8_t* rangeBegin = cast(uint8_t*) range.first;
                uint8_t* rangeEnd = cast(uint8_t*) (range.second - patternLen);
                ptrdiff_t index;

                try {

                    while (rangeBegin <= rangeEnd)
                        {
                            for (index = patternLen - 1; index >= 0; --index)
                                {
                                    if ((pbytes[index] & pmask[index]) != (rangeBegin[index] & pmask[index]))
                                        {
                                            break;
                                        }
                                }

                            if (index == -1)
                                {
                                    this._results ~= new MemoryPointer(rangeBegin);
                                    rangeBegin += patternLen;
                                }
                            else
                                {
                                    rangeBegin += max(index - this._bmbc[rangeBegin[index]], 1);
                                }
                        }
                    
                } catch (Exception e) {
                    debugOutput(e.toString());
                }
            }
    };

    BytePattern search()
    {
        bmSearch();
        debugOutput();
        return this;
    };
    
    BytePattern findPattern(string patternLiteral)
    {
        debugOutput(mixin(interp!"findPattern str: ${hexToUTF8(patternLiteral)},hex: ${patternLiteral}"));
        this.setPattern(patternLiteral).search();
        return this;
    };
    
    static Stream logStream(string logFilePath=null)
    {
        if (this._stream is null)
            {
                const string mode = existsAsFile(logFilePath) ? "a+" : "w+";
                auto fout = File(logFilePath, mode);
                this._stream = new FileStream(fout);
            }

        return this._stream;
    };
    
public:
    /++
     + デバッグログを出力する
     +
     + Example:
     + ---
     + // 内部に検索結果の文字列が格納されている場合それも出力する
     + Result(s) of pattern: 455534
     + 
     + // 以下のようにすればasciiに戻せる
     + $ echo "455534" | xxd -r -p
     + EU4
     + ---
     +/
    void debugOutput()
    {
        if (this._stream is null)
            {
                return;
            }
        
        logStream().write(cast(ubyte[]) _literal.format!("Result(s) of pattern: %(%02X%)"));
        logStream().write(cast(ubyte[]) "\n");

        if (count() > 0)
            {
                foreach (pointer; _results)
                    {
                        logStream().write(cast(ubyte[]) pointer.address().format!("0x%s"));
                        logStream().write(cast(ubyte[]) "\n");                
                    }
            }
        else
            {
                logStream().write(cast(ubyte[]) "None");
                logStream().write(cast(ubyte[]) "\n");
            }
        
        logStream().write(cast(ubyte[]) sep);
        logStream().write(cast(ubyte[]) "\n");
        _stream.seek(0, Seek.set);
    };

    void debugOutput(const string message)
    {
        if (this._stream is null)
            {
                return;
            }

        logStream().write(cast(ubyte[]) message);
        logStream().write(cast(ubyte[]) "\n");        
        logStream().write(cast(ubyte[]) sep);
        logStream().write(cast(ubyte[]) "\n");
        
        _stream.seek(0, Seek.set);
    };
    
    static void startLog(const string moduleName)
    {
        shutdownLog();
        // TODO: EU4と同じディレクトリに書き込もうとするとno such file or directoryとなるため
        // とりあえず１つ上のディレクトリに書き込んでいる、単体のプログラムだと問題が再現しない
        Path logFilePath = Path(thisExePath()).up().up() ~ mixin(interp!"pattern_${moduleName}.log");
        tempInstance().logStream(logFilePath.toString());
    };

    static void shutdownLog()
    {
        if (_stream !is null)
            {
                _stream = null;
            }
    };

    MemoryPointer get(size_t index)
    {
        return this._results[index];
    };

    MemoryPointer getFirst()
    {
        return this.get(0);
    };

    MemoryPointer getSecond()
    {
        return this.get(1);
    };

    BytePattern setPattern(string patternLiteral)
    {
        transformPattern(patternLiteral);
        bmPreprocess();
        return this;
    };
    
    BytePattern setModule()
    {
        version(Windows)
            {
                
            }
        else
            {
                // GetModuleHandle(NULL) on Linux
                // https://stackoverflow.com/questions/6972211/getmodulehandlenull-on-linux
                MemoryPointer dll = new MemoryPointer(dlopen(null, RTLD_LAZY));
                return setModule(dll);
            }
    };

    BytePattern setModule(MemoryPointer mod)
    {
        this.getModuleRanges(mod);
        return this;
    };
};
