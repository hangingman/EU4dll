module plugin.byte_pattern;


import core.stdc.stdint;
import core.sys.posix.dlfcn;
import elf;
import freck.streams.filestream;
import freck.streams.stream;
import plugin.memory_pointer;
import scriptlike.core;
import scriptlike.path.extras : Path;
import std.container : Array;
import std.file : thisExePath;
import std.stdio;
import std.typecons;
import std.array : replicate;
import std.format;
import std.range;


alias Range = Tuple!(uintptr_t, "first", uintptr_t, "second");
alias Pat = Tuple!(uint8_t, "first", uint8_t, "second");


class BytePattern
{
    Array!(Range) _ranges;
    Array!(uint8_t) _pattern;
    Array!(uint8_t) _mask;
    Array!(MemoryPointer) _results;
    string _literal;
    ptrdiff_t[256] _bmbc;
    static Stream _stream = null;
    const string sep = replicate("-", 80);

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
                    // TODO: 最初のセクションを格納
                    
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
    };

    static Stream logStream(string logFilePath=null)
    {
        if (this._stream is null)
            {
                this._stream = new FileStream(logFilePath, "w+");
            }

        return this._stream;
    };
    
public:
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
        Path logFilePath = Path(thisExePath()).up() ~ mixin(interp!"pattern_${moduleName}.log");
        logStream(logFilePath.toString());
    };

    static void shutdownLog()
    {
        if (_stream !is null)
            {
                _stream = null;
            }
    };

    static typeof(this) tempInstance()
    {
        return new BytePattern();
    };

    this()
    {
        setModule();
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
