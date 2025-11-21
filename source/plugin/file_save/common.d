module plugin.file_save.common;
import plugin.constant;

import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import std.stdio; // writeln を使用するため

// DllError型はplugin.inputで定義されているため、ここで再定義はしない

// 共通で利用されるextern(C)関数宣言
extern (C)
{
    void* fileSaveProc1() { return null; }
    void* fileSaveProc2() { return null; }
    void* fileSaveProc3() { return null; }
    void* fileSaveProc3V130() { return null; }
    void* fileSaveProc3V1316() { return null; }
    void* fileSaveProc4() { return null; }
    void* fileSaveProc5() { return null; }
    void* fileSaveProc5V130() { return null; }
    void* fileSaveProc5V1316() { return null; }
    void* fileSaveProc6() { return null; }
    void* fileSaveProc6V130() { return null; }
    void* fileSaveProc7() { return null; }
}

// 共通で利用されるアドレス変数
__gshared size_t fileSaveProc1ReturnAddress;
__gshared size_t fileSaveProc2ReturnAddress;
__gshared size_t fileSaveProc2CallAddress;
__gshared size_t fileSaveProc3ReturnAddress;
__gshared size_t fileSaveProc3CallAddress;
__gshared size_t fileSaveProc3CallAddress2;
__gshared size_t fileSaveProc4ReturnAddress;
__gshared size_t fileSaveProc4CallAddress;
__gshared size_t fileSaveProc4MarkerAddress;
__gshared size_t fileSaveProc5ReturnAddress;
__gshared size_t fileSaveProc5CallAddress;
__gshared size_t fileSaveProc5MarkerAddress;
__gshared size_t fileSaveProc6ReturnAddress;
__gshared size_t fileSaveProc6CallAddress;
__gshared size_t fileSaveProc6MarkerAddress;
__gshared size_t fileSaveProc7ReturnAddress;
__gshared size_t fileSaveProc7CallAddress;

// Helper functions (placeholders for now, need actual implementation or import)
// In C++ these are imported from escape_tool.h
extern (C) void escapedStrToUtf8()
{
    writeln("Dummy escapedStrToUtf8 called");
}

extern (C) void utf8ToEscapedStr()
{
    writeln("Dummy utf8ToEscapedStr called");
}

extern (C) void utf8ToEscapedStr2()
{
    writeln("Dummy utf8ToEscapedStr2 called");
}
