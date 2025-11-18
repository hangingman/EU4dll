module plugin.patcher.patcher;

import core.sys.linux.sys.mman;
import std.stdio;
import std.exception;
import core.stdc.string : memcpy;
import core.atomic;
import core.stdc.stdlib : malloc, free; // 手動メモリ管理用

/// メモリにパッチを適用する
void patch_memory(void* address, const ubyte[] data)
{
    import core.sys.posix.unistd;
    long pageSize = sysconf(_SC_PAGESIZE);
    enforce(pageSize != -1, "sysconf(_SC_PAGESIZE) failed");

    void* pageAddress = cast(void*)(cast(size_t)address & ~(pageSize - 1));
    void* endAddress = cast(void*)(cast(size_t)address + data.length);
    size_t len = cast(size_t)endAddress - cast(size_t)pageAddress;

    // (a) 書き込み権限付与
    enforce(mprotect(pageAddress, len, PROT_READ | PROT_WRITE) == 0, "mprotect for write failed");

    // (b) パッチ書き込み
    memcpy(address, data.ptr, data.length);

    // メモリバリア
    atomicFence();

    // (c) 実行権限復元
    enforce(mprotect(pageAddress, len, PROT_READ | PROT_EXEC) == 0, "mprotect for execute failed");
}

/// RAIIでメモリパッチを管理する構造体 (Structを使用)
struct ScopedPatch
{
private:
    void* _address;       // パッチ対象のアドレス
    ubyte* _backupData;   // 元データのバックアップ (mallocで確保)
    size_t _dataLength;   // データの長さ
    bool _applied;        // パッチ適用済みフラグ

public:
    // コピー禁止 (二重解放を防ぐため)
    @disable this(this);

    /// コンストラクタ：パッチを適用し、元データをmalloc領域に退避
    this(void* address, const ubyte[] patchData)
    {
        _address = address;
        _dataLength = patchData.length;
        _applied = false;

        // 1. GCを使わず、mallocでバックアップ領域を確保
        _backupData = cast(ubyte*)malloc(_dataLength);
        if (_backupData is null)
        {
            import core.exception : onOutOfMemoryError;
            onOutOfMemoryError();
        }

        // 2. 現在のメモリ内容（元データ）をバックアップ領域にコピー
        memcpy(_backupData, address, _dataLength);

        // 3. パッチを適用
        patch_memory(_address, patchData);
        _applied = true;
    }

    /// デストラクタ：スコープを抜けた瞬間に元データを復元し、freeする
    ~this()
    {
        if (_applied && _address !is null)
        {
            // 1. 元のデータを復元
            // backupDataをスライスとして扱いpatch_memoryに渡す
            patch_memory(_address, _backupData[0 .. _dataLength]);

            // 2. mallocしたメモリを解放
            free(_backupData);
            
            _address = null;
            _backupData = null;
            _applied = false;
        }
    }
}

unittest
{
    import std.stdio;
    writeln("Starting ScopedPatch unittest...");

    ubyte[] dummyFunc = [0x55, 0x48, 0x89, 0xE5, 0xC3]; // Original
    ubyte[] patchData = [0x90, 0x90, 0x90, 0x90, 0x90]; // NOPs

    // メモリを確保して実行可能にする
    void* mem = mmap(null, dummyFunc.length, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    enforce(mem != MAP_FAILED, "mmap failed");
    memcpy(mem, dummyFunc.ptr, dummyFunc.length);

    // ブロックスコープを作成
    {
        // structなので new を使わず直接宣言する
        auto patch = ScopedPatch(mem, patchData);
        
        // パッチが当たっていることを確認
        assert((cast(ubyte*)mem)[0 .. 5] == patchData);
    } 
    // <--- ここでスコープを抜けるため、ScopedPatch.~this() が即座に実行される

    // スコープを抜けたので、メモリは元に戻っているはず
    auto currentMem = (cast(ubyte*)mem)[0 .. 5].dup;
    
    writeln("Memory after scope: ", currentMem);
    writeln("Expected:           ", dummyFunc);

    assert(currentMem == dummyFunc);

    // メモリを解放
    munmap(mem, dummyFunc.length);
}
