module plugin.input.proc3;

import plugin.byte_pattern;
import plugin.constant;
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.input; // 共通変数・構造体を使用するため
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import std.stdio; // writeln を使用するため

import plugin.misc; // get_branch_destination_offset を使用するため

DllError InputProc3Injector(RunOptions options)
{
    DllError e;
    string pattern;
    size_t address;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // mov     [rsp+18h], rbx
        pattern = "48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(3, "メッセージ入力欄の取得をフック(3個目)"))
        {
            address = BytePattern.tempInstance().get(2).address; // 修正

            InputProc3CallAddress = cast(size_t)&cursor;

            // mov     [rsp+18h], rbx
            InputProc3ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc3));
            writeln("JMP for InputProc3Injector created.");
        }
        else
        {
            e.unmatchdInputProc3Injector = true;
        }
        break;
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
        // mov     [rsp+18h], rbx
        pattern = "48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(3, "メッセージ入力欄の取得をフック(3個目)"))
        {
            address = BytePattern.tempInstance().get(2).address;

            InputProc3CallAddress = cast(size_t)&cursor;

            // mov     [rsp+18h], rbx
            InputProc3ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc3V130));
            writeln("JMP for InputProc3Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdInputProc3Injector = true;
        }
        break;
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
        // mov     [rsp+18h], rbx
        pattern = "48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(3, "メッセージ入力欄の取得をフック(3個目)"))
        {
            address = BytePattern.tempInstance().get(2).address; // 修正

            InputProc3CallAddress = cast(size_t)&cursor;

            // mov     [rsp+18h], rbx
            InputProc3ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc3V131));
            writeln("JMP for InputProc3Injector (v1_31_plus) created.");
        }
        else
        {
            e.unmatchdInputProc3Injector = true;
        }
        break;
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // mov     [rsp+18h], rbx
        pattern = "48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(3, "メッセージ入力欄の取得をフック(3個目)"))
        {
            address = BytePattern.tempInstance().get(2).address; // 修正

            InputProc3CallAddress = cast(size_t)&cursor;

            // mov     [rsp+18h], rbx
            InputProc3ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc3V132));
            writeln("JMP for InputProc3Injector (v1_32_plus) created.");
        }
        else
        {
            e.unmatchdInputProc3Injector = true;
        }
        break;
    default:
        e.versionInputProc3Injector = true;
    }

    return e;
}
