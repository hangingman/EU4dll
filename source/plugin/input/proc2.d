module plugin.input.proc2;

import plugin.byte_pattern;
import plugin.constant;
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.input; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

import plugin.misc; // get_branch_destination_offset を使用するため

DllError InputProc2Injector(RunOptions options)
{
    DllError e;
    string pattern;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // mov     [rsp+18h], rbx
        BytePattern.tempInstance().findPattern("48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9");
        if (BytePattern.tempInstance().hasSize(2, "メッセージ入力欄の取得をフック(2個目)"))
        {
            size_t address = BytePattern.tempInstance().get(1).address; // 修正

            // mov     [rsp+18h], rbx
            InputProc2ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc2));
            writeln("JMP for InputProc2Injector created.");
        }
        else
        {
            e.unmatchdInputProc2Injector = true;
        }
        break;
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
        // mov     [rsp+18h], rbx
        BytePattern.tempInstance().findPattern("48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9");
        if (BytePattern.tempInstance().hasSize(2, "メッセージ入力欄の取得をフック(2個目)"))
        {
            size_t address = BytePattern.tempInstance().getSecond().address;

            // mov     [rsp+18h], rbx
            InputProc2ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc2V130));
            writeln("JMP for InputProc2Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdInputProc2Injector = true;
        }
        break;
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // mov     [rsp+18h], rbx
        BytePattern.tempInstance().findPattern("48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9");
        if (BytePattern.tempInstance().hasSize(2, "メッセージ入力欄の取得をフック(2個目)"))
        {
            size_t address = BytePattern.tempInstance().getSecond().address;

            // mov     [rsp+18h], rbx
            InputProc2ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc2V131));
            writeln("JMP for InputProc2Injector (v1_31_plus) created.");
        }
        else
        {
            e.unmatchdInputProc2Injector = true;
        }
        break;
    default:
        e.versionInputProc2Injector = true;
    }

    return e;
}
