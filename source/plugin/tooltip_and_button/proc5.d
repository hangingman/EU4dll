module plugin.tooltip_and_button.proc5;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.tooltip_and_button.common; // 共通の関数と変数をインポート

DllError tooltipAndButtonProc5Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // movaps  xmm7, [rsp+0E8h+var_48]
        BytePattern.tempInstance().findPattern("0F 28 BC 24 A0 00 00 00 48 8B B4 24 00 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ツールチップの改行処理のリターン先２")) {
            tooltipAndButtonProc5ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdTooltipAndButtonProc5Injector = true;
        }

        // movzx   edx, byte ptr [rbx+r14]
        BytePattern.tempInstance().findPattern("42 0F B6 14 33 49 8D 8C 24 00 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ツールチップの改行処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz short loc_xxxxx
            tooltipAndButtonProc5ReturnAddress1 = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc5));
            writeln("JMP for tooltipAndButtonProc5Injector created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc5Injector = true;
        }
        break;
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
        // movaps  xmm7, [rsp+0E8h+var_48]
        BytePattern.tempInstance().findPattern("0F 28 BC 24 A0 00 00 00 48 8B B4 24 00 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ツールチップの改行処理のリターン先２")) {
            tooltipAndButtonProc5ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdTooltipAndButtonProc5Injector = true;
        }

        // movzx   edx, byte ptr [rbx+r14]
        BytePattern.tempInstance().findPattern("42 0F B6 14 33 49 8D 8C 24 20 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ツールチップの改行処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz short loc_xxxxx
            tooltipAndButtonProc5ReturnAddress1 = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc5V130));
            writeln("JMP for tooltipAndButtonProc5Injector (v1_30_X) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc5Injector = true;
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
        // movaps  xmm8, [rsp+0F8h+var_58]
        BytePattern.tempInstance().findPattern("44 0F 28 84 24 A0 00 00 00 0F 28 BC 24 B0 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ツールチップの改行処理のリターン先２")) {
            tooltipAndButtonProc5ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdTooltipAndButtonProc5Injector = true;
        }

        // movzx   edx, byte ptr [rbx+r14]
        BytePattern.tempInstance().findPattern("42 0F B6 14 33 49 8D 8C 24 20 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ツールチップの改行処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz short loc_xxxxx
            tooltipAndButtonProc5ReturnAddress1 = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc5V130));
            writeln("JMP for tooltipAndButtonProc5Injector (v1_31_X_plus) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc5Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc5Injector = true;
    }

    return e;
}
