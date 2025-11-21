module plugin.tooltip_and_button.proc3;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.tooltip_and_button.common; // 共通の関数と変数をインポート

DllError tooltipAndButtonProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0:
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
        // mov ecx, ebx
        BytePattern.tempInstance().findPattern("8B CB F3 45 0F 10 97 48 08 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ２の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // test r11, r11
            tooltipAndButtonProc3ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc3));
            writeln("JMP for tooltipAndButtonProc3Injector created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc3Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc3Injector = true;
    }

    return e;
}
