module plugin.input.common;

import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import std.stdio; // writeln を使用するため

import plugin.input; // DllError, RunOptions を使用するため
import plugin.misc; // get_branch_destination_offset を使用するため
import plugin.byte_pattern; // BytePattern を使用するため
import plugin.constant; // EU4Ver を使用するため

// 共通で利用されるextern(C)関数宣言
extern(C) {
    void* InputProc1() { return null; }
    void* InputProc2() { return null; }
    void* InputProc3() { return null; }
    void* InputProc4() { return null; }
    void* InputProc5() { return null; }
    void* InputProc6() { return null; }
    void* InputProc7() { return null; }
    void* InputProc8() { return null; }
    void* InputProc9() { return null; }
    void* InputProc10() { return null; }
    void* InputProc11() { return null; }
    void* InputProc12() { return null; }

    void* InputProc1V130() { return null; }
    void* InputProc2V130() { return null; }
    void* InputProc3V130() { return null; }
    void* InputProc4V130() { return null; }
    void* InputProc5V130() { return null; }
    void* InputProc6V130() { return null; }
    void* InputProc7V130() { return null; }
    void* InputProc8V130() { return null; }
    void* InputProc9V130() { return null; }
    void* InputProc10V130() { return null; }
    void* InputProc11V130() { return null; }
    void* InputProc12V130() { return null; }

    void* InputProc1V131() { return null; }
    void* InputProc2V131() { return null; }
    void* InputProc3V131() { return null; }
    void* InputProc4V131() { return null; }
    void* InputProc5V131() { return null; }
    void* InputProc6V131() { return null; }
    void* InputProc7V131() { return null; }
    void* InputProc8V131() { return null; }
    void* InputProc9V131() { return null; }
    void* InputProc10V131() { return null; }
    void* InputProc11V131() { return null; }
    void* InputProc12V131() { return null; }

    void* InputProc1V132() { return null; }
    void* InputProc2V132() { return null; }
    void* InputProc3V132() { return null; }
    void* InputProc4V132() { return null; }
    void* InputProc5V132() { return null; }
    void* InputProc6V132() { return null; }
    void* InputProc7V132() { return null; }
    void* InputProc8V132() { return null; }
    void* InputProc9V132() { return null; }
    void* InputProc10V132() { return null; }
    void* InputProc11V132() { return null; }
    void* InputProc12V132() { return null; }

    void* InputProc1V133() { return null; }
    void* InputProc2V133() { return null; }
    void* InputProc3V133() { return null; }
    void* InputProc4V133() { return null; }
    void* InputProc5V133() { return null; }
    void* InputProc6V133() { return null; }
    void* InputProc7V133() { return null; }
    void* InputProc8V133() { return null; }
    void* InputProc9V133() { return null; }
    void* InputProc10V133() { return null; }
    void* InputProc11V133() { return null; }
    void* InputProc12V133() { return null; }

    void* InputProc1V134() { return null; }
    void* InputProc2V134() { return null; }
    void* InputProc3V134() { return null; }
    void* InputProc4V134() { return null; }
    void* InputProc5V134() { return null; }
    void* InputProc6V134() { return null; }
    void* InputProc7V134() { return null; }
    void* InputProc8V134() { return null; }
    void* InputProc9V134() { return null; }
    void* InputProc10V134() { return null; }
    void* InputProc11V134() { return null; }
    void* InputProc12V134() { return null; }

    void* InputProc1V135() { return null; }
    void* InputProc2V135() { return null; }
    void* InputProc3V135() { return null; }
    void* InputProc4V135() { return null; }
    void* InputProc5V135() { return null; }
    void* InputProc6V135() { return null; }
    void* InputProc7V135() { return null; }
    void* InputProc8V135() { return null; }
    void* InputProc9V135() { return null; }
    void* InputProc10V135() { return null; }
    void* InputProc11V135() { return null; }
    void* InputProc12V135() { return null; }

    void* InputProc1V136() { return null; }
    void* InputProc2V136() { return null; }
    void* InputProc3V136() { return null; }
    void* InputProc4V136() { return null; }
    void* InputProc5V136() { return null; }
    void* InputProc6V136() { return null; }
    void* InputProc7V136() { return null; }
    void* InputProc8V136() { return null; }
    void* InputProc9V136() { return null; }
    void* InputProc10V136() { return null; }
    void* InputProc11V136() { return null; }
    void* InputProc12V136() { return null; }

    void* InputProc1V137() { return null; }
    void* InputProc2V137() { return null; }
    void* InputProc3V137() { return null; }
    void* InputProc4V137() { return null; }
    void* InputProc5V137() { return null; }
    void* InputProc6V137() { return null; }
    void* InputProc7V137() { return null; }
    void* InputProc8V137() { return null; }
    void* InputProc9V137() { return null; }
    void* InputProc10V137() { return null; }
    void* InputProc11V137() { return null; }
    void* InputProc12V137() { return null; }

    void* InputProc1V138() { return null; }
    void* InputProc2V138() { return null; }
    void* InputProc3V138() { return null; }
    void* InputProc4V138() { return null; }
    void* InputProc5V138() { return null; }
    void* InputProc6V138() { return null; }
    void* InputProc7V138() { return null; }
    void* InputProc8V138() { return null; }
    void* InputProc9V138() { return null; }
    void* InputProc10V138() { return null; }
    void* InputProc11V138() { return null; }
    void* InputProc12V138() { return null; }

    void* InputProc1V139() { return null; }
    void* InputProc2V139() { return null; }
    void* InputProc3V139() { return null; }
    void* InputProc4V139() { return null; }
    void* InputProc5V139() { return null; }
    void* InputProc6V139() { return null; }
    void* InputProc7V139() { return null; }
    void* InputProc8V139() { return null; }
    void* InputProc9V139() { return null; }
    void* InputProc10V139() { return null; }
    void* InputProc11V139() { return null; }
    void* InputProc12V139() { return null; }
}

// 共通で利用されるアドレス変数
__gshared size_t InputProc1ReturnAddress;
__gshared size_t InputProc2ReturnAddress;
__gshared size_t InputProc3ReturnAddress;
__gshared size_t InputProc4ReturnAddress;
__gshared size_t InputProc5ReturnAddress;
__gshared size_t InputProc6ReturnAddress;
__gshared size_t InputProc7ReturnAddress;
__gshared size_t InputProc8ReturnAddress;
__gshared size_t InputProc9ReturnAddress;
__gshared size_t InputProc10ReturnAddress;
__gshared size_t InputProc11ReturnAddress;
__gshared size_t InputProc12ReturnAddress;

__gshared size_t InputProc3CallAddress;
__gshared size_t InputProc4CallAddress;
__gshared size_t InputProc5CallAddress;
__gshared size_t InputProc6CallAddress;
__gshared size_t InputProc7CallAddress;
__gshared size_t InputProc8CallAddress;
__gshared size_t InputProc9CallAddress;
__gshared size_t InputProc10CallAddress;
__gshared size_t InputProc11CallAddress;
__gshared size_t InputProc12CallAddress;

// 構造体（仮）
struct Cursor
{
    size_t x;
    size_t y;
    size_t width;
    size_t height;
}

// init関数内で初期化されるオブジェクト
__gshared Cursor cursor;
__gshared size_t cursorAddress;

struct Ime
{
    size_t isCandidateListWindowOpened;
    size_t x;
    size_t y;
    size_t width;
    size_t height;
}
__gshared Ime ime;
__gshared size_t imeAddress;
