module plugin.memory_pointer;
import plugin.constant;


import core.stdc.stdint;
import std.stdio;


class MemoryPointer
{
    union
    {
        void* Pointer;
        uintptr_t Address;
    };
    size_t byteLength;

    this()
    {
        this.Pointer = Pointer.init;
        this.byteLength = 0;
    }

    this(void *p, size_t byteLength = 0)
    {
        this.Pointer = p;
        this.byteLength = byteLength;
    }

    this(uintptr_t i, size_t byteLength = 0)
    {
        this.Address = i;
        this.byteLength = byteLength;
    }

    uintptr_t address(ptrdiff_t offset = 0)
    {
        return (this.Address + offset);
    }
};
