module plugin.memory_pointer;


import core.stdc.stdint;
import std.stdio;


class MemoryPointer
{
    union
    {
        void* Pointer;
        uintptr_t Address;
    };

    this()
    {
        this.Pointer = Pointer.init;
    }

    this(void *p)
    {
        this.Pointer = p;
    }

    this(uintptr_t i)
    {
        this.Address = i;
    }

    uintptr_t address(ptrdiff_t offset = 0)
    {
        return (this.Address + offset);
    }

    const(T*) pointer(T)(ptrdiff_t offset = 0)
    {
        return cast(T*)(this.address(offset));
    }

    // MemoryPointer opCast(uintptr)()
    // {
    //     writeln("opCast");
    //     return this.address();
    // }
};
