module plugin.localization.common;
import plugin.constant;

import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import std.stdio; // writeln を使用するため

// DllError型はplugin.inputで定義されているため、ここで再定義はしない

// 共通で利用されるextern(C)関数宣言
extern(C) {
    void* localizationProc2() { return null; }
    void* localizationProc3() { return null; }
    void* localizationProc3V130() { return null; }
    void* localizationProc4() { return null; }
    void* localizationProc4V130() { return null; }
    void* localizationProc5() { return null; }
    void* localizationProc5V131() { return null; }
    void* localizationProc6() { return null; }
    void* localizationProc7() { return null; }
    void* localizationProc7V131() { return null; }
    void* localizationProc8() { return null; }
}

// 共通で利用されるアドレス変数
__gshared size_t localizationProc1CallAddress1;
__gshared size_t localizationProc1CallAddress2;
__gshared size_t localizationProc2ReturnAddress;
__gshared size_t localizationProc3ReturnAddress;
__gshared size_t localizationProc4ReturnAddress;
__gshared size_t localizationProc5ReturnAddress;
__gshared size_t localizationProc6ReturnAddress;
__gshared size_t localizationProc7ReturnAddress;
__gshared size_t localizationProc8ReturnAddress;
__gshared size_t localizationProc7CallAddress1;
__gshared size_t localizationProc7CallAddress2;
__gshared size_t generateCString;
__gshared size_t concatCString;
__gshared size_t concat2CString;
__gshared size_t year;
__gshared size_t month;
__gshared size_t day;

// ParadoxTextObjectに相当する構造体（仮）
// 実際の定義はplugin_64.hにあるはずだが、ここでは簡易的に定義
struct ParadoxTextObject {
    char[11] text; // C++のParadoxTextObjectはchar配列を直接持つため、それに合わせる
    size_t len;
    size_t len2;
}

// init関数内で初期化されるオブジェクト
__gshared ParadoxTextObject _year;
__gshared ParadoxTextObject _month;
__gshared ParadoxTextObject _day;
