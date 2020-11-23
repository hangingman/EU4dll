module plugin.test_memory_pointer;

import plugin.memory_pointer;

@("default constructor")
unittest
{
    auto t = new MemoryPointer();
    assert(t !is null);
}
