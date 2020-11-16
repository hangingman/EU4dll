module plugin.test_byte_pattern;

import std.file : thisExePath;
import scriptlike.file.extras : existsAsFile, tryRemove;
import scriptlike.path.extras : Path;
import scriptlike.core;
import plugin.memory_pointer;
import plugin.byte_pattern;
import core.sys.posix.dlfcn;
import std.stdio;
import std.file;
import std.array;


@("default constructor")
unittest
{
    auto b = new BytePattern();
    assert(b !is null);
}

@("digitToValue")
unittest
{
    auto b = BytePattern.tempInstance();
    assert(0==b.digitToValue('0'));
    assert(9==b.digitToValue('9'));
    assert(10==b.digitToValue('A'));
    assert(15==b.digitToValue('F'));
    assert(10==b.digitToValue('a'));
    assert(15==b.digitToValue('f'));
}

@("transformPattern")
unittest
{
    auto b = BytePattern.tempInstance();
    // Hello World!
    b.transformPattern("48 65 6C 6C 6F 20 57 6F 72 6C 64 21");
    assert(b._literal == "48 65 6C 6C 6F 20 57 6F 72 6C 64 21");
    assert(b._pattern.length == 12);
    assert(b._mask.length == 12);

    // 16進数が10進数に変換される
    assert(b._pattern[0] == 72, mixin(interp!"${b._pattern[0]} != 72"));
}

@("startLog")
unittest
{
    Path logFilePath = Path(thisExePath()).up() ~ mixin(interp!"pattern_unittest1.log");
    tryRemove(logFilePath);
    
    auto b = new BytePattern();
    b.startLog("unittest1");
    b.debugOutput("Hello,EU4!");
    
    assert(existsAsFile(logFilePath.toString()));
    
    const string[] logs = readText(logFilePath.toString()).split("\n");
    assert(logs !is null);
    assert(logs.length == 3);
    assert(logs[0] == "Hello,EU4!");
    assert(logs[1] == replicate("-", 80));
}

@("debugOutput")
unittest
{
    Path logFilePath = Path(thisExePath()).up() ~ mixin(interp!"pattern_unittest2.log");
    tryRemove(logFilePath);
    
    auto b = new BytePattern();
    b.startLog("unittest2");
    b._literal = "Hello World!";
    b.debugOutput();
    
    assert(existsAsFile(logFilePath.toString()));
    
    const string[] logs = readText(logFilePath.toString()).split("\n");
    assert(logs !is null);
    assert(logs.length == 4);
    assert(logs[0] == "Result(s) of pattern: 48656C6C6F20576F726C6421");
    assert(logs[1] == "None");
    assert(logs[2] == replicate("-", 80));
}

@("tempInstance")
unittest
{
    auto b = BytePattern.tempInstance();
    assert(b !is null);
}

@("empty")
unittest
{
    auto b = BytePattern.tempInstance();
    assert(b.empty());
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
    assert(b._ranges[1].first == 901952);
    assert(b._ranges[1].second == 993632);
}
