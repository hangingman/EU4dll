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
import std.container;
import fluent.asserts;
import std.mmfile;


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

@("hexToUTF8")
unittest
{
    auto b = BytePattern.tempInstance();
    b.hexToUTF8("48656c6c6f20576f726c6421").should.equal("Hello World!");
    b.hexToUTF8("48 65 6C 6C 6F 20 57 6F 72 6C 64 21").should.equal("Hello World!");
    b.hexToUTF8("45 55 34 20 76 31 2E ? ? 2E ?").should.equal("EU4 v1.**.*");
}

@("binToRange")
unittest
{
    auto b = BytePattern.tempInstance();
    Path binPath = Path(__FILE__).up().up() ~ "elf-Linux-lib-x64.so";
    Bytes contents = b.binToRange(binPath.toString());
    contents.length.should.equal(1145944);
    contents[0].should.equal(0x7F);
    contents[1..4].should.equal(cast(ubyte[])['E', 'L', 'F']);
}

@("findIndexes")
unittest
{
    Path binPath = Path(__FILE__).up().up() ~ "elf-Linux-lib-x64.so";
    auto b = BytePattern.tempInstance();

    with (b)
        {
            // ELFを検索
            setModule(binPath.toString());
            setPattern("45 4C 46");
            _ranges = make!Array(SectionRange(0, 100, 0)); // fileOffset, size, virtualAddress
            findIndexes(binPath.toString());
            _results.length.should.equal(1);
            _results[0].address.should.equal(1); // fileOffset + index
        }

    with (b)
        {
            // E?Fを検索
            setModule(binPath.toString());
            setPattern("45 ?? 46");
            _ranges = make!Array(SectionRange(0, 100, 0)); // fileOffset, size, virtualAddress
            findIndexes(binPath.toString());
            _results.length.should.equal(1);
            _results[0].address.should.equal(1); // fileOffset + index
        }

}


@("transformPattern")
unittest
{
    auto b = BytePattern.tempInstance();
    // Hello World!
    b.transformPattern("48 65 6C 6C 6F 20 57 6F 72 6C 64 21");
    assert(b._literal == "48 65 6C 6C 6F 20 57 6F 72 6C 64 21");
    assert(b._maskedPattern.length == 12);

    // 16進数が10進数に変換される
    assert(b._maskedPattern[0].pattern == 72, mixin(interp!"${b._maskedPattern[0].pattern} != 72"));
}

@("parseSubPattern")
unittest
{
    // 2byte単位でmaskを作成する(maskしている部分はワイルドカード扱い)
    auto b = BytePattern.tempInstance();
    b.parseSubPattern("??").should.equal(Pat(0x00, 0x00));
    b.parseSubPattern("8?").should.equal(Pat(0x80, 0xF0));
    b.parseSubPattern("?8").should.equal(Pat(0x08, 0x0F));
    b.parseSubPattern("88").should.equal(Pat(0x88, 0xFF));
}

@("startLog")
unittest
{
    Path logFilePath = Path(thisExePath()).up().up() ~ mixin(interp!"pattern_unittest1.log");
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
    Path logFilePath = Path(thisExePath()).up().up() ~ mixin(interp!"pattern_unittest2.log");
    tryRemove(logFilePath);

    auto b = new BytePattern();
    b.startLog("unittest2");
    b._literal = "48656C6C6F20576F726C6421";
    b.debugOutput();

    assert(existsAsFile(logFilePath.toString()));

    const string[] logs = readText(logFilePath.toString()).split("\n");
    assert(logs !is null);
    assert(logs.length == 5);

    logs[0].should.equal("Result(s) of pattern: 48656C6C6F20576F726C6421");
    logs[1].should.equal("(Hello World!)");
    logs[2].should.equal("None");
    logs[3].should.equal(replicate("-", 80));
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

@("getModuleRanges")
unittest
{
    // elf-Linux-lib-x64.so をテストする
    auto b = BytePattern.tempInstance();
    Path binPath = Path(__FILE__).up().up() ~ "elf-Linux-lib-x64.so";

    with (b)
        {
            getModuleRanges(binPath.toString());
            assert(_ranges.length==2);

            // text
            assert(_ranges[0].fileOffset == 88160);
            assert(_ranges[0].size == 813756);
            assert(_ranges[0].virtualAddress == 88160);
            // rodata
            assert(_ranges[1].fileOffset == 901952);
            assert(_ranges[1].size == 91680);
            assert(_ranges[1].virtualAddress == 901952);
        }

    with (b)
        {
            MmFile mmf = new MmFile(binPath.toString(), MmFile.Mode.read, 0, null);
            getModuleRanges(mmf);
            assert(_ranges.length==2);

            // text
            assert(_ranges[0].fileOffset == 88160);
            assert(_ranges[0].size == 813756);
            assert(_ranges[0].virtualAddress == 88160);
            // rodata
            assert(_ranges[1].fileOffset == 901952);
            assert(_ranges[1].size == 91680);
            assert(_ranges[1].virtualAddress == 901952);
        }
}
