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

@("getModuleRanges")
unittest
{
    // elf-Linux-lib-x64.so をテストする
    auto b = BytePattern.tempInstance();
    Path binPath = Path(__FILE__).up().up() ~ "elf-Linux-lib-x64.so";
    b.getModuleRanges(null, binPath.toString());

    assert(b._ranges.length==2);

    // text
    assert(b._ranges[0].first == 88160);
    assert(b._ranges[0].second == 901916);
    // rodata
    writeln(b._ranges[1]);
    assert(b._ranges[1].first == 901952);
    assert(b._ranges[1].second == 993632);
}
