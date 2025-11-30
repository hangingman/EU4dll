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
import std.conv; // `to!string` を使用するためにインポート
import std.path; // `dirName` を使用するためにインポート
import std.algorithm; // `map` を使用するためにインポート
import std.string; // `chomp` を使用するためにインポート

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
    assert(0 == b.digitToValue('0'));
    assert(9 == b.digitToValue('9'));
    assert(10 == b.digitToValue('A'));
    assert(15 == b.digitToValue('F'));
    assert(10 == b.digitToValue('a'));
    assert(15 == b.digitToValue('f'));
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
    BytePattern.clearContentsCache(); // キャッシュをクリア
    auto b = BytePattern.tempInstance();
    string binPath = std.path.dirName(std.path.dirName(__FILE_FULL_PATH__)) ~ "/elf-Linux-lib-x64.so"; // パスを修正
    std.stdio.writeln("binToRange test: binPath = ", binPath); // デバッグ出力
    Bytes contents = b.binToRange(binPath);

    std.stdio.writeln("binToRange test: contents.length = ", contents.length); // デバッグ出力
    contents.length.should.equal(1145944); // ファイルサイズを修正
    contents[0].should.equal(0x7F);
    contents[1 .. 4].should.equal(cast(ubyte[])[0x45, 0x4C, 0x46]); // 直接バイト値で比較 (キャスト修正)
}

@("findIndexes")
unittest
{
    string binPath = std.path.dirName(std.path.dirName(__FILE_FULL_PATH__)) ~ "/elf-Linux-lib-x64.so"; // パスを修正
    auto b = BytePattern.tempInstance();

    with (b)
    {
        // ELFを検索
        setModule(binPath); // .toString() を削除
        getModuleRanges(binPath); // 追加
        // .textセクションの先頭バイトパターンを検索
        setPattern("55 48 8d");
        findIndexes(binPath); // .toString() を削除
        _results.length.should.equal(1);
        _results[0].address.should.equal(88160); // .textセクションのvirtualAddress

    }

    with (b)
    {
        // .textセクションの先頭バイトパターンをワイルドカードで検索
        setModule(binPath); // .toString() を削除
        getModuleRanges(binPath); // 追加
        setPattern("55 ?? 8d");
        findIndexes(binPath); // .toString() を削除
        _results.length.should.equal(1);
        _results[0].address.should.equal(88160); // .textセクションのvirtualAddress
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
    b._literal = "48656C6C6F2C45553421"; // "Hello,EU4!" の16進数表現をセット
    b.debugOutput(); // 引数なしのdebugOutputを呼び出す

    assert(existsAsFile(logFilePath.toString()));

    const ubyte[] actualLogs = cast(ubyte[])std.file.read(logFilePath.toString()); // cast(ubyte[])std.file.read に変更

    // 期待するログ内容をバイト列として定義
    const ubyte[] expectedLogs = cast(ubyte[])( // cast(ubyte[]) を追加
        "Result(s) of pattern: 48656C6C6F2C45553421\n" ~
            "(Hello,EU4!)\n" ~
            "None\n" ~
            replicate("-", 80) ~ "\n"
    ); // .to!ubyte[] を削除

    assert(actualLogs == expectedLogs); // バイト列同士で直接比較
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

    const ubyte[] actualLogs = cast(ubyte[])std.file.read(logFilePath.toString()); // cast(ubyte[])std.file.read に変更

    // 期待するログ内容をバイト列として定義
    const ubyte[] expectedLogs = cast(ubyte[])( // cast(ubyte[]) を追加
        "Result(s) of pattern: 48656C6C6F20576F726C6421\n" ~
            "(Hello World!)\n" ~
            "None\n" ~
            replicate("-", 80) ~ "\n"
    ); // .to!ubyte[] を削除

    assert(actualLogs == expectedLogs); // バイト列同士で直接比較
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
    string binPath = std.path.dirName(std.path.dirName(__FILE_FULL_PATH__)) ~ "/elf-Linux-lib-x64.so"; // パスを修正

    with (b)
    {
        getModuleRanges(binPath); // .toString() を削除
        assert(_ranges.length == 2);

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
        MmFile mmf = new MmFile(binPath, MmFile.Mode.read, 0, null); // .toString() を削除
        getModuleRanges(mmf);
        assert(_ranges.length == 2);

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
