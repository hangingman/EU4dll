module plugin.input.proc12;

import plugin.byte_pattern;
import plugin.constant;
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.input; // 共通変数・構造体を使用するため
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import std.stdio; // writeln を使用するため

import plugin.misc; // get_branch_destination_offset を使用するため

DllError InputProc12Injector(RunOptions options)
{
    DllError e;
    string pattern;
    size_t address;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // mov     r9, [rsp+50h+var_30]
        pattern = "4C 8B 4C 24 20 48 83 C1 10 4C 8D 44 24 50";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(8, "メッセージ入力欄の取得をフック(12個目)"))
        {
            address = BytePattern.tempInstance().get(7).address; // 修正

            InputProc12CallAddress = cast(size_t)&cursor;

            // mov     r9, [rsp+50h+var_30]
            InputProc12ReturnAddress = address + 0xE;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc12));
            writeln("JMP for Input12Injector created.");
        }
        else
        {
            e.unmatchdInputProc12Injector = true;
        }
        break;
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
        // mov     r9, [rsp+50h+var_30]
        pattern = "4C 8B 4C 24 20 48 83 C1 10 4C 8D 44 24 50";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(8, "メッセージ入力欄の取得をフック(12個目)"))
        {
            address = BytePattern.tempInstance().get(7).address; // 修正

            InputProc12CallAddress = cast(size_t)&cursor;

            // mov     r9, [rsp+50h+var_30]
            InputProc12ReturnAddress = address + 0xE;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc12V130));
            writeln("JMP for Input12Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdInputProc12Injector = true;
        }
        break;
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
        // mov     r9, [rsp+50h+var_30]
        pattern = "4C 8B 4C 24 20 48 83 C1 10 4C 8D 44 24 50";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(8, "メッセージ入力欄の取得をフック(12個目)"))
        {
            address = BytePattern.tempInstance().get(7).address; // 修正

            InputProc12CallAddress = cast(size_t)&cursor;

            // mov     r9, [rsp+50h+var_30]
            InputProc12ReturnAddress = address + 0xE;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc12V131));
            writeln("JMP for Input12Injector (v1_31_plus) created.");
        }
        else
        {
            e.unmatchdInputProc12Injector = true;
        }
        break;
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // mov     r9, [rsp+50h+var_30]
        pattern = "4C 8B 4C 24 20 48 83 C1 10 4C 8D 44 24 50";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(8, "メッセージ入力欄の取得をフック(12個目)"))
        {
            address = BytePattern.tempInstance().get(7).address;

            InputProc12CallAddress = cast(size_t)&cursor;

            // mov     r9, [rsp+50h+var_30]
            InputProc12ReturnAddress = address + 0xE;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc12V132));
            writeln("JMP for Input12Injector (v1_32_plus) created.");
        }
        else
        {
            e.unmatchdInputProc12Injector = true;
        }
        break;
    default:
        e.versionInputProc12Injector = true;
    }

    return e;
}
