module plugin.byte_pattern;


import std.typecons;
import core.stdc.stdint;
import std.container : Array;
import std.file : thisExePath;
import freck.streams.stream;
import freck.streams.filestream;
import scriptlike.path.extras : Path;
import scriptlike.core;
import plugin.memory_pointer;


class BytePattern
{
    Array!(Tuple!(uintptr_t, uintptr_t)) _ranges;
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

    void getModuleRanges(ref MemoryPointer memoryPointer)
    {
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

    // static ref BytePattern tempInstance()
    // {
    //     return this;
    // };

    this()
    {
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
};
