module plugin.byte_pattern;


import std.typecons;
import core.stdc.stdint;
import std.container : DList;
import plugin.memory_pointer;


class BytePattern
{
    DList!(Tuple!(uintptr_t, uintptr_t)) _ranges;
    DList!(uint8_t) _pattern;
    DList!(uint8_t) _mask;
    DList!(MemoryPointer) _results;
    string _literal;
    ptrdiff_t[256] _bmbc;

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

    logStream()
    {
    };
    
public:
    void debugOutput(const string message)
    {
    };
    
    static void startLog(const string moduleName)
    {
    };

    static void shutdownLog()
    {
    };

    // static ref BytePattern tempInstance()
    // {
    //     return this;
    // };

    this()
    {
    };
};
