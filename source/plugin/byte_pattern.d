module plugin.byte_pattern;
import plugin.constant;

import core.stdc.stdint;
import core.sys.posix.dlfcn;
import elf;
// import freck.streams.filestream; // freck-streams を削除
// import freck.streams.stream;     // freck-streams を削除
import plugin.memory_pointer;
import plugin.singleton;
import scriptlike.core;
import scriptlike.file.extras : existsAsFile;
import scriptlike.file.wrappers : readText;
import scriptlike.path.extras : Path;
import std.conv;
import std.container : Array, SList;
import std.file : thisExePath;
import std.stdio; // std.stdio のすべてをインポートし、writeln, File, SeekPos を解決
import core.stdc.stdio : SEEK_SET; // SEEK_SET をインポート
import std.typecons;
import std.array : replicate;
import std.format;
import std.range;
import std.algorithm;
import core.stdc.stdlib;
import std.algorithm.searching : BoyerMooreFinder;
import cerealed;
import std.mmfile;


alias SectionRange = Tuple!(size_t, "fileOffset", size_t, "size", uintptr_t, "virtualAddress");
alias Pat = Tuple!(uint8_t, "pattern", uint8_t, "mask");
alias Patterns = Pat[];
alias Bytes = ubyte[];


class BytePattern
{
    // シングルトンパターン
    mixin singleton;

    Bytes[string] _contents;
    Array!(SectionRange) _ranges;
    Patterns _maskedPattern;
    Array!(MemoryPointer) _results;
    string _literal;
    ptrdiff_t[256] _bmbc;
    static File _stream = File.init; // Stream から std.stdio.File に変更
    const string sep = replicate("-", 80);

    static typeof(this) tempInstance()
    {
        // シングルトンのインスタンスを返す
        return BytePattern.opCall();
    }

    this()
    {
        setModule();
    }

    // キャッシュをクリアするメソッド
    static void clearContentsCache()
    {
        BytePattern.opCall()._contents.clear();
    }

    uint8_t digitToValue(uint8_t ch)
    {
        if ('0' <= ch && ch <= '9')
            {
                return cast(uint8_t) (ch - '0');
            }
        else if ('A' <= ch && ch <= 'F')
            {
                return cast(uint8_t) (ch - 'A' + 10);
            }
        else if ('a' <= ch && ch <= 'f')
            {
                return cast(uint8_t) (ch - 'a' + 10);
            }

        throw new Exception("Could not parse pattern.");
    }

    string hexToUTF8(string hex)
    {
        return hex.replace(" ", "")
            .replace("?", "2A")
            .chunks(2)
            .map!(digits => cast(char) digits.to!ubyte(16))
            .to!string;
    }

    Bytes binToRange(string binPath = thisExePath())
    {
        if (auto content = binPath in _contents)
            {
                return *content;
            }
        // freck-streams の FileStream の代わりに std.stdio.File を使用
        auto f = File(binPath, "r");
        scope(exit) f.close(); // ファイルを必ず閉じる
        size_t size = f.size;
        ubyte[] content = new ubyte[size];
        f.rawRead(content); // rawRead に引数スライスを渡す
        _contents[binPath] = content;
        return _contents[binPath];
    }

    Pat parseSubPattern(string sub)
    {
        // パターンマッチを使いたいが、D言語にはない
        Pat result;

        if (sub.length == 1)
            {
                if (sub[0] == '?')
                    {
                        result.pattern = 0;
                        result.mask = 0;
                    }
                else
                    {
                        result.pattern = digitToValue(sub[0]);
                        result.mask = 0xFF;
                    }
            }
        else if (sub.length == 2)
            {
                if (sub[0] == '?' && sub[1] == '?')
                    {
                        result.pattern = 0;
                        result.mask = 0;
                    }
                else if (sub[0] == '?')
                    {
                        result.pattern = digitToValue(sub[1]);
                        result.mask = 0xF;
                    }
                else if (sub[1] == '?')
                    {
                        result.pattern = cast(uint8_t) (digitToValue(sub[0]) << 4);
                        result.mask = 0xF0;
                    }
                else
                    {
                        result.pattern = cast(uint8_t) ((digitToValue(sub[0]) << 4) | digitToValue(sub[1]));
                        result.mask = 0xFF;
                    }
            }
        else
            {
                throw new Exception("Could not parse pattern.");
            }

        return result;
    }

    void transformPattern(string literal)
    {
        clear();
        _literal = literal;

        if (literal.empty())
            {
                return;
            }

        Array!(string) subPatterns = _literal.split(" ");

        try
            {
                foreach (sub; subPatterns)
                    {
                        auto pat = parseSubPattern(sub);
                        _maskedPattern ~= pat;
                    }
            }
        catch (Exception e)
            {
                this.clear();
            }
    }

    // elf-dの実装でも、内部的にはファイルをMmFileとして扱っている
    // https://github.com/yazd/elf-d/blob/master/source/elf/package.d
    void getModuleRanges(MmFile mmf)
    {
        ELF elf = ELF.fromFile(mmf);
        setModuleRanges(elf);
    }

    void getModuleRanges(string binPath = thisExePath())
    {
        ELF elf = ELF.fromFile(binPath);
        setModuleRanges(elf);
    }

    void setModuleRanges(ELF elf)
    {
        // 実行ファイルのすべてのセクションテーブルを取得し、その開始アドレス終了アドレスを
        // _ranges に格納する(ELFでの実装のみ対応)
        _ranges.clear();

        foreach (section; elf.sections) {
            if (section.name == ".text" || section.name == ".rodata")
            {
                SectionRange range;
                range.fileOffset = section.offset;
                range.size = section.size;
                range.virtualAddress = section.address;
                _ranges.insertBack(range);
            }
        }
    }

    void clear()
    {
        _literal = "";
        _maskedPattern = [];
        _results.clear();
    }

    size_t count()
    {
        return _results.length;
    }

    bool hasSize(size_t expected, string desc)
    {
        return true;
    }

    bool empty()
    {
        return _results.empty();
    }

    void findIndexes(string binPath = thisExePath())
    {
        findIndexes(binToRange(binPath));
    }

    void findIndexes(in ubyte[] contents)
    {
        const Patterns pattern = this._maskedPattern.dup;
        const size_t patternLen = this._maskedPattern.length;
        this._results.clear();

        if (patternLen == 0)
            {
                return;
            }

        foreach (range ; this._ranges)
            {
                debug {
                    std.stdio.writeln(mixin(interp!"module size: ${contents.length}"));
                    // import plugin.constant; // constantは既にインポート済み

                    std.stdio.writeln(mixin(interp!"[${range.fileOffset} .. ${range.fileOffset + range.size}]"));

                    std.stdio.writeln("pattern:");
                    std.stdio.writeln(pattern.map!(d => std.conv.to!string(d.pattern, 16) ));
                    std.stdio.writeln("mask:");
                    std.stdio.writeln(pattern.map!(d => std.conv.to!string(d.mask, 16) ));
                }

                auto section = contents[range.fileOffset .. range.fileOffset + range.size];
                ptrdiff_t index = std.algorithm.searching.countUntil!((a, b) // 完全修飾名を使用
                                              {
                                                  return (a & b.mask) == (b.pattern & b.mask);
                                              })(section, pattern);

                if (index != -1)
                    {
                        MemoryPointer m = new MemoryPointer(range.virtualAddress + index, patternLen);
                        this._results.insertBack(m);
                        debug {
                            std.stdio.writeln((range.virtualAddress + index).format!"Found on: %d");
                            std.stdio.writeln(section[index .. index + patternLen].map!(d => std.conv.to!string(d, 16) ));
                        }
                    }
            }
    }

    BytePattern search()
    {
        findIndexes();
        debugOutput();
        return this;
    }

    BytePattern findPattern(string patternLiteral)
    {
        debugOutput(mixin(interp!"findPattern str: ${hexToUTF8(patternLiteral)},hex: ${patternLiteral}"));
        this.setPattern(patternLiteral).search();
        return this;
    }

    T found(T)()
    {
        auto m = getFirst();
        const ubyte[] content = binToRange()[m.address() .. m.address(m.byteLength)];
        debug {
            std.stdio.writeln("-- found --");
            std.stdio.writeln(m.address().format!("from %d"));
            std.stdio.writeln(m.address(m.byteLength).format!("to %d"));
            std.stdio.writeln(content.map!(d => std.conv.to!string(d, 16) ));
        }
        T ans = cerealed.decerealise!T(content); // 完全修飾名を使用
        return ans;
    }

    T findPattern(T)(string patternLiteral)
    {
        findPattern(patternLiteral);
        auto m = getFirst();
        return found!T(); // テンプレートの呼び出しを修正
    }

    static File logStream(string logFilePath=null) // std.stdio.File を返す
    {
        if (this._stream == File.init) // File.init で未初期化を判定
            {
                this._stream = File(logFilePath, "a+");
            }

        return this._stream;
    }

public:
    /++
     + デバッグログを出力する
     +
     + Example:
     + ---
     + // 内部に検索結果の文字列が格納されている場合それを出力する
     + Result(s) of pattern: 45 55 34
     +
     + // 以下のようにすればasciiに戻せる
     + $ echo "45 55 34" | sed -e 's/ //g' | xxd -r -p
     + EU4
     + ---
     +/
    void debugOutput()
    {
        if (this._stream == File.init) // File.init で未初期化を判定
            {
                return;
            }

    // writeln の代わりに rawWrite と明示的な改行コードを使用
    _stream.rawWrite(cast(ubyte[])(_literal.format!"Result(s) of pattern: %s"));
    _stream.rawWrite(cast(ubyte[])"\n");
    _stream.rawWrite(cast(ubyte[])(hexToUTF8(_literal).format!"(%s)"));
    _stream.rawWrite(cast(ubyte[])"\n");

    if (count() > 0)
        {
            foreach (pointer; _results)
                {
                    _stream.rawWrite(cast(ubyte[])(pointer.address().format!("0x%s")));
                    _stream.rawWrite(cast(ubyte[])"\n");
                }
        }
    else
        {
            _stream.rawWrite(cast(ubyte[])"None");
            _stream.rawWrite(cast(ubyte[])"\n");
        }

    _stream.rawWrite(cast(ubyte[])sep);
    _stream.rawWrite(cast(ubyte[])"\n");
        _stream.seek(0, SEEK_SET); // SEEK_SET を使用
    }

    void debugOutput(const string message)
    {
        if (this._stream == File.init) // File.init で未初期化を判定
            {
                return;
            }

        logStream().writeln(message); // writeln を使用
        logStream().writeln(sep); // writeln を使用

        _stream.seek(0, SEEK_SET); // SEEK_SET を使用
    }

    static void startLog(const string moduleName)
    {
        shutdownLog();
        // TODO: EU4と同じディレクトリに書き込もうとするとno such file or directoryとなるため
        // とりあえず１つ上のディレクトリに書き込んでいる、単体のプログラムだと問題が再現しない
        Path logFilePath = Path(thisExePath()).up().up() ~ mixin(interp!"pattern_${moduleName}.log");
        tempInstance().logStream(logFilePath.toString());
    }

    static void shutdownLog()
    {
        if (_stream != File.init) // File.init で未初期化を判定
            {
                _stream.close();
                _stream = File.init;
            }
    }

    MemoryPointer get(size_t index)
    {
        return this._results[index];
    }

    MemoryPointer getFirst()
    {
        return this.get(0);
    }

    MemoryPointer getSecond()
    {
        return this.get(1);
    }

    void flushLog()
    {
        if (_stream != File.init) // File.init で未初期化を判定
        {
            _stream.flush(); // std.stdio.File の flush() を呼び出す
        }
    }

    BytePattern setPattern(string patternLiteral)
    {
        transformPattern(patternLiteral);
        return this;
    }

    BytePattern setModule(string binPath = thisExePath())
    {
        this.getModuleRanges(binPath);
        return this;
    }

    BytePattern setMmFile(MmFile mmf)
    {
        this.getModuleRanges(mmf);
        return this;
    }
}
