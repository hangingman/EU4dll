module plugin.tooltip_and_button.proc1;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.tooltip_and_button.common; // 共通の関数と変数をインポート

DllError tooltipAndButtonProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
        // r8d, byte ptr [rax + rcx]
        BytePattern.tempInstance().findPattern("44 0F B6 04 08 BA 01 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字コピー")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx}
            // tooltipAndButtonProc1CallAddress = Injector::GetBranchDestination(address + 0x0F).as_int();
            tooltipAndButtonProc1CallAddress = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // Placeholder

            // nop
            tooltipAndButtonProc1ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc1V133));
            writeln("JMP for tooltipAndButtonProc1Injector (v1_33_3_0) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc1Injector = true;
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
        // r8d, byte ptr [rax + rcx]
        BytePattern.tempInstance().findPattern("44 0F B6 04 08 BA 01 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字コピー")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx}
            // tooltipAndButtonProc1CallAddress = Injector::GetBranchDestination(address + 0x0E).as_int();
            tooltipAndButtonProc1CallAddress = address + 0x0E + get_branch_destination_offset(cast(void*)(address + 0x0E), 4); // Placeholder
            
            // nop
            tooltipAndButtonProc1ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc1));
            writeln("JMP for tooltipAndButtonProc1Injector created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc1Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc1Injector = true;
    }

    return e;
}
