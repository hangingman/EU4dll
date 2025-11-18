module plugin.process.process;

import core.sys.elf;
import core.sys.linux.link;
import core.sys.posix.dlfcn;
import elf;
import std.stdio;
import std.typecons;

extern (C) int callback(dl_phdr_info* info, size_t size, void* data) nothrow
{
    // `info.dlpi_name` が空文字列の場合、それがメインの実行可能ファイル
    if (info.dlpi_name != null && info.dlpi_name[0] == '\0') {
        auto pinfo = cast(dl_phdr_info*)data;
        *pinfo = *info;
        return 1; // 探索を終了
    }
    return 0;
}

/// メイン実行可能ファイルのメモリ範囲を取得する
auto get_executable_memory_range()
{
    dl_phdr_info info;
    dl_iterate_phdr(&callback, &info);

    foreach (i; 0 .. info.dlpi_phnum) {
        const phdr = info.dlpi_phdr[i];
        // PT_LOAD 型で実行可能なセグメント（.textセクションを含む）を探す
        if (phdr.p_type == PT_LOAD && (phdr.p_flags & PF_X)) {
            auto start = info.dlpi_addr + phdr.p_vaddr;
            auto end = start + phdr.p_memsz;
            return tuple(start, end);
        }
    }

    return tuple(cast(size_t)0, cast(size_t)0);
}

unittest
{
    auto range = get_executable_memory_range();
    assert(range[0] != 0);
    assert(range[1] != 0);
    assert(range[0] < range[1]);
}
