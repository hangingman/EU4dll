module plugin.test_byte_pattern;

import std.file : thisExePath;
import scriptlike.file.extras : existsAsFile, tryRemove;
import scriptlike.path.extras : Path;
import scriptlike.core;
import plugin.memory_pointer;
import plugin.byte_pattern;
import core.sys.posix.dlfcn;
import std.stdio;


@("default constructor")
unittest
{
    auto b = new BytePattern();
    assert(b !is null);
}

@("startLog")
unittest
{
    Path logFilePath = Path(thisExePath()).up() ~ mixin(interp!"pattern_unittest.log");
    tryRemove(logFilePath);
    
    auto b = new BytePattern();
    b.startLog("unittest");
    assert(existsAsFile(logFilePath.toString()));
}

@("tempInstance")
unittest
{
    auto b = BytePattern.tempInstance();
    assert(b !is null);
}

@("setModule")
unittest
{
    MemoryPointer dll = new MemoryPointer(dlopen(null, RTLD_LAZY));
    assert(dll !is null);
    dll.address();
}

