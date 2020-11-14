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


alias Range = Tuple!(uintptr_t, "first", uintptr_t, "second");


class BytePattern
{
    Array!(Range) _ranges;
    Array!(uint8_t) _pattern;
    Array!(uint8_t) _mask;
    Array!(MemoryPointer) _results;
    string _literal;
    ptrdiff_t[256] _bmbc;
    static Stream _stream = null;

    Tuple!(uint8_t, uint8_t) parseSubPattern()
    {
        return tuple(cast(uint8_t) 0x00, cast(uint8_t) 0x00);
    };

    void transformPattern()
    {
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

    void bmPreprocess()
    {
    };

    void bmSearch()
    {
    };

    void debugOutput()
    {
    };

    static Stream logStream(string logFilePath=null)
    {
        if (this._stream is null)
            {
                this._stream = new FileStream(logFilePath, "w+");
            }

        assert(logFilePath !is null);
        return this._stream;
    };
    
public:
    void debugOutput(const string message)
    {
    };
    
    static void startLog(const string moduleName)
    {
        Path logFilePath = Path(thisExePath()).up() ~ mixin(interp!"pattern_${moduleName}.log");
        logStream(logFilePath.toString());
    };

    static void shutdownLog()
    {
        // NOP
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
