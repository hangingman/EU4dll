module plugin.tooltip_and_button.proc2;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.tooltip_and_button.common; // 共通の関数と変数をインポート

DllError tooltipAndButtonProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
        // mov edx, ebx
        BytePattern.tempInstance().findPattern("8B D3 0F B6 04 10 49 8B 0C C7");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // test rcx,rcx
            tooltipAndButtonProc2ReturnAddress = address + 0xE;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc2V133));
            writeln("JMP for tooltipAndButtonProc2Injector (v1_33_3_0) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc2Injector = true;
        }
        break;
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
        // mov edx, ebx
        BytePattern.tempInstance().findPattern("8B D3 0F B6 04 10 49 8B 0C C7");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // test rcx,rcx
            tooltipAndButtonProc2ReturnAddress = address + 0x11;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc2));
            writeln("JMP for tooltipAndButtonProc2Injector created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc2Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc2Injector = true;
    }

    return e;
}
