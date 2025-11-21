module plugin.tooltip_and_button.proc4;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.tooltip_and_button.common; // 共通の関数と変数をインポート

DllError tooltipAndButtonProc4Injector(RunOptions options) {
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
        // cmp word ptr [rcx + 6], 0
        BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 05 03 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の改行処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jnz {loc_xxxxx} / inc ebx
            // tooltipAndButtonProc4ReturnAddress1 = Injector::GetBranchDestination(address + 0x5).as_int();
            tooltipAndButtonProc4ReturnAddress1 = address + 0x05 + get_branch_destination_offset(cast(void*)(address + 0x05), 4); // Placeholder

            // jz loc_xxxxx
            tooltipAndButtonProc4ReturnAddress2 = address + 15;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc4));
            writeln("JMP for tooltipAndButtonProc4Injector created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc4Injector = true;
        }
        break;
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
        // cmp word ptr [rcx + 6], 0
        BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 11 03 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の改行処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jnz {loc_xxxxx} / inc ebx
            // tooltipAndButtonProc4ReturnAddress1 = Injector::GetBranchDestination(address + 0x5).as_int();
            tooltipAndButtonProc4ReturnAddress1 = address + 0x05 + get_branch_destination_offset(cast(void*)(address + 0x05), 4); // Placeholder

            // jz loc_xxxxx
            tooltipAndButtonProc4ReturnAddress2 = address + 15;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc4));
            writeln("JMP for tooltipAndButtonProc4Injector (v1_32/33) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc4Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
        // cmp word ptr [rcx + 6], 0
        BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 03 03 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の改行処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jnz {loc_xxxxx} / inc ebx
            // tooltipAndButtonProc4ReturnAddress1 = Injector::GetBranchDestination(address + 0x5).as_int();
            tooltipAndButtonProc4ReturnAddress1 = address + 0x05 + get_branch_destination_offset(cast(void*)(address + 0x05), 4); // Placeholder

            // jz loc_xxxxx
            tooltipAndButtonProc4ReturnAddress2 = address + 15;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc4V133));
            writeln("JMP for tooltipAndButtonProc4Injector (v1_33_3_0) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc4Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc4Injector = true;
    }

    return e;
}
