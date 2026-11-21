module plugin.patcher.patcher;
import plugin.constant;

import core.sys.linux.sys.mman;
import std.stdio;
import std.exception;
import core.stdc.string : memcpy;
import core.atomic;
import core.stdc.stdlib : malloc, free; // 手動メモリ管理用（今回はGC管理に変更するが、mmap/munmapは残す）
import std.array; // 今回は直接動的配列を管理するためAppenderは使用しない
import core.memory; // GC を使用するため

// JMP/CALL命令を生成するヘルパー関数
private ubyte[] makeJmpCall(void* fromAddress, void* toAddress, ubyte opcode)
{
    ubyte[] instruction = [
        opcode, // JMP (E9) or CALL (E8) opcode
        0x00, 0x00, 0x00,
        0x00 // Placeholder for relative address
    ];
    // 相対アドレスを計算: target - (source + instruction_length)
    long relativeAddress = cast(long) toAddress - (cast(long) fromAddress + instruction.length);

    // リトルエンディアンで4バイトの相対アドレスをセット
    instruction[1] = cast(ubyte)(relativeAddress & 0xFF);
    instruction[2] = cast(ubyte)((relativeAddress >> 8) & 0xFF);
    instruction[3] = cast(ubyte)((relativeAddress >> 16) & 0xFF);
    instruction[4] = cast(ubyte)((relativeAddress >> 24) & 0xFF);

    return instruction;
}

/// Length in bytes of the absolute indirect jump used on Linux:
/// FF 25 00 00 00 00 followed by the 8-byte little-endian target address.
/// This is the form proven by the SetText hook (see
/// memory-bank/details/linux_patching_details.md section 3): it reaches
/// any 64-bit address, unlike the 5-byte rel32 jump, whose range is
/// limited to +/-2 GiB and fails for far-apart Linux mappings.
enum size_t absoluteJmpLength = 14;

/// Build the 14-byte absolute indirect JMP (FF 25 00000000 + address).
/// Pure, so the encoding can be unit tested without patching memory.
ubyte[] makeAbsoluteJmp(void* toAddress)
{
    auto address = cast(size_t) toAddress;
    ubyte[] instruction = [0xFF, 0x25, 0x00, 0x00, 0x00, 0x00];
    foreach (shift; [0, 8, 16, 24, 32, 40, 48, 56])
        instruction ~= cast(ubyte)(address >> shift);
    return instruction;
}

/// Absolute jump padded with NOPs to exactly patchLength bytes.
/// The caller must pass the length of complete instructions being
/// overwritten (the SetText site uses 17: the 14-byte jump + 3 NOPs).
/// Throws when patchLength cannot hold the absolute jump.
ubyte[] makeAbsoluteJmpPadded(void* toAddress, size_t patchLength)
{
    import std.exception : enforce;
    enforce(patchLength >= absoluteJmpLength,
        "patch length is smaller than the 14-byte absolute jump");
    auto instruction = makeAbsoluteJmp(toAddress);
    foreach (_; absoluteJmpLength .. patchLength)
        instruction ~= cast(ubyte) 0x90;
    return instruction;
}

/// Build the legacy 5-byte relative JMP (E9 rel32). Kept for callers
/// that explicitly need the relative form; new Linux hooks must use
/// makeJmp / makeAbsoluteJmp instead.
ubyte[] makeJmpRel(void* fromAddress, void* toAddress)
{
    return makeJmpCall(fromAddress, toAddress, 0xE9);
}

/// JMP instruction for hooks. On Linux this is the proven 14-byte
/// absolute jump, not the 5-byte rel32 form: fromAddress is kept only
/// for signature compatibility with the relative form and is unused.
/// WARNING: the patch overwrites 14 bytes at the target. The caller
/// must overwrite only complete instructions totalling at least 14
/// bytes, and any trampoline that copies the original prefix must copy
/// exactly the patched length. Callers whose trampoline copies a
/// shorter fixed prefix must use makeJmpRel instead (see
/// reload_trace.d, which copies 8 bytes).
ubyte[] makeJmp(void* fromAddress, void* toAddress)
{
    return makeAbsoluteJmp(toAddress);
}

/// CALL命令のバイト列を生成する
ubyte[] makeCall(void* fromAddress, void* toAddress)
{
    return makeJmpCall(fromAddress, toAddress, 0xE8);
}

/// メモリにパッチを適用する
void patch_memory(void* address, const ubyte[] data)
{
    import core.sys.posix.unistd;

    long pageSize = sysconf(_SC_PAGESIZE);
    enforce(pageSize != -1, "sysconf(_SC_PAGESIZE) failed");

    void* pageAddress = cast(void*)(cast(size_t) address & ~(pageSize - 1));
    void* endAddress = cast(void*)(cast(size_t) address + data.length);
    size_t len = cast(size_t) endAddress - cast(size_t) pageAddress;

    // (a) 書き込み権限付与
    enforce(mprotect(pageAddress, len, PROT_READ | PROT_WRITE) == 0, "mprotect for write failed");

    // (b) パッチ書き込み
    memcpy(address, data.ptr, data.length);

    // メモリバリア
    atomicFence();

    // (c) 実行権限復元
    enforce(mprotect(pageAddress, len, PROT_READ | PROT_EXEC) == 0, "mprotect for execute failed");
}

/// RAIIでメモリパッチを管理する構造体
struct ScopedPatch
{
private:
    void* _address; // パッチ対象のアドレス
    ubyte[] _backupData; // 元データのバックアップ (GCで管理)
    size_t _dataLength; // データの長さ
    bool _applied; // パッチ適用済みフラグ

public:
    /// コンストラクタ：パッチを適用し、元データを退避
    this(void* address, const ubyte[] patchData)
    {
        _address = address;
        _dataLength = patchData.length;
        _applied = false;

        // 1. GCを使わず、mallocでバックアップ領域を確保 --> D言語の動的配列に変更
        _backupData = new ubyte[_dataLength];

        // 2. 現在のメモリ内容（元データ）をバックアップ領域にコピー
        memcpy(_backupData.ptr, address, _dataLength);

        // 3. パッチを適用
        patch_memory(_address, patchData);
        _applied = true;
    }

    /// デストラクタ：オブジェクトがスコープを抜ける前に元のデータを復元
    ~this()
    {
        if (_applied && _address !is null)
        {
            // 元のデータを復元
            patch_memory(_address, _backupData[0 .. _dataLength]);

            _address = null;
            _applied = false;
        }
    }
}

/// 適用されたパッチを管理するシングルトン
class PatchManager
{
private:
    static PatchManager _instance;
    private ScopedPatch[] _patches; // 適用されたパッチのリスト (動的配列で管理)

    this()
    {
        // _patchesAppender の初期化は不要 (直接動的配列を管理するため)
    } // シングルトンなのでプライベートコンストラクタ

public:
    static PatchManager instance()
    {
        if (_instance is null)
        {
            _instance = new PatchManager();
        }
        return _instance;
    }

    /// パッチを適用し、管理リストに追加する
    void addPatch(void* address, const ubyte[] patchData)
    {
        _patches ~= ScopedPatch(address, patchData); // struct なので new は不要
    }

    /// Apply the proven 14-byte absolute jump at address towards
    /// destination, managed like any other patch. patchLength is the
    /// number of bytes of complete instructions being overwritten and
    /// must be at least absoluteJmpLength; the jump is NOP-padded to it.
    void addJmpPatch(void* address, void* destination, size_t patchLength = absoluteJmpLength)
    {
        addPatch(address, makeAbsoluteJmpPadded(destination, patchLength));
    }

    /// Number of patches currently managed (for tests and logging).
    size_t patchCount()
    {
        return _patches.length;
    }

    // 必要に応じて、内部配列へのアクセスを提供する
    ScopedPatch[] patches()
    {
        return _patches;
    }
}

unittest
{
    import std.stdio;

    writeln("Starting ScopedPatch unittest...");

    // makeJmp/makeCall のテスト
    writeln("Testing makeJmp/makeCall...");
    void* func_a = cast(void*) 0x10000;
    void* func_b = cast(void*) 0x10010;
    ubyte[] jmp_instr = makeJmp(func_a, func_b);
    ubyte[] call_instr = makeCall(func_a, func_b);

    // makeJmp is now the 14-byte absolute jump proven by the SetText
    // hook: FF 25 00000000 followed by the 8-byte target address.
    assert(jmp_instr.length == absoluteJmpLength);
    assert(jmp_instr[0 .. 6] == [0xFF, 0x25, 0x00, 0x00, 0x00, 0x00]);
    assert(jmp_instr[6 .. 14] == [0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]);
    assert(makeAbsoluteJmp(func_b) == jmp_instr);
    // A target far outside the rel32 range still encodes exactly.
    auto far = cast(void*) 0x7F12_3456_789A;
    auto farJmp = makeJmp(func_a, far);
    assert(farJmp[6 .. 14] == [0x9A, 0x78, 0x56, 0x34, 0x12, 0x7F, 0x00, 0x00]);
    // The relative form remains available under its explicit name.
    auto relJmp = makeJmpRel(func_a, func_b);
    assert(relJmp.length == 5 && relJmp[0] == 0xE9);
    // NOP padding fills exactly the overwritten instruction span.
    auto padded = makeAbsoluteJmpPadded(func_b, 17);
    assert(padded.length == 17);
    assert(padded[0 .. 14] == jmp_instr);
    assert(padded[14 .. 17] == [0x90, 0x90, 0x90]);
    bool paddingRejected = false;
    try
        makeAbsoluteJmpPadded(func_b, 13);
    catch (Exception)
        paddingRejected = true;
    assert(paddingRejected);
    assert(call_instr.length == 5);
    assert(call_instr[0] == 0xE8);

    writeln("makeJmp/makeCall tests passed.");

    writeln("Starting ScopedPatch unittest...");

    ubyte[] dummyFunc = [
        0x55, 0x48, 0x89, 0xE5, 0xC3
    ]; // Original
    ubyte[] patchData = [0x90, 0x90, 0x90, 0x90, 0x90]; // NOPs

    // メモリを確保して実行可能にする
    void* mem = mmap(null, dummyFunc.length, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    enforce(mem != MAP_FAILED, "mmap failed");
    memcpy(mem, dummyFunc.ptr, dummyFunc.length);

    // ブロックスコープを作成
    {
        // struct なので new は不要
        auto patch = ScopedPatch(mem, patchData);

        // パッチが当たっていることを確認
        assert((cast(ubyte*) mem)[0 .. 5] == patchData);

        // patch のスコープを抜ける前に明示的に null にして、GC に回収させる
        // D言語のGCは確定的なデストラクタ呼び出しを保証しないため、
        // RAIIの性質を持つクラスの場合、必要に応じて明示的に操作するか、
        // std.experimental.scope を利用するなどの工夫が必要になる場合があります。
        // ここでは簡単にテストするため、スコープ外でメモリ復元を確認します。
    }
    // <--- ここで ScopedPatch のインスタンスは GC 対象になる

    // GCが実行されるのを待つ（保証はされないが、テストのために明示的に実行）
    // import std.stdio; // writeln のため
    // GC.collect(); // ここでデストラクタが呼ばれることを期待
    // GC.minimize();

    // メモリが元に戻っていることを確認（GCがデストラクタを呼んだ場合）
    auto currentMem = (cast(ubyte*) mem)[0 .. 5].dup;

    writeln("Memory after scope: ", currentMem); // GCではなくスコープを抜けた直後の状態を確認
    writeln("Expected:           ", dummyFunc);

    // GCによるデストラクタ呼び出しは保証されないため、このassertは不安定になる可能性がある
    // 今回は、もしデストラクタが呼ばれていれば元のデータに戻っていることを確認
    import std.algorithm; // equal を使用するため
    assert(currentMem.equal(dummyFunc)); // 元のデータに戻っていることを確認する

    // メモリを解放
    munmap(mem, dummyFunc.length);
}
