module plugin.input.proc1;

import plugin.byte_pattern;
import plugin.constant;
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.input; // 共通変数・構造体を使用するため
import std.logger;

import plugin.misc; // get_branch_destination_offset を使用するため

DllError InputProc1Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
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
        BytePattern.tempInstance()
            .findPattern(
                "48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0 4C 8B F1 4C 8B F2 4C 8B F9");
        if (BytePattern.tempInstance().hasSize(1, "メッセージ入力欄の取得をフック"))
        {
            size_t address = BytePattern.tempInstance().get(0).address; // 修正

            // mov     [rsp+18h], rbx
            InputProc1ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) InputProc1));
            std.logger.info("JMP for InputProc1Injector created.");
        }
        else
        {
            e.unmatchdInputProc1Injector = true;
        }
        break;
    default:
        e.versionInputProc1Injector = true;
    }

    return e;
}
