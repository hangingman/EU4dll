module plugin.tooltip_and_button.proc7;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.tooltip_and_button.common; // 共通の関数と変数をインポート

DllError tooltipAndButtonProc7Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
        // inc ebx
        BytePattern.tempInstance().findPattern("FF C3 3B 5D A8 7D 1D E9 79 F7 FF FF E8");
        if (BytePattern.tempInstance().hasSize(1, "カウントアップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jmp loc_xxxxx
            // tooltipAndButtonProc7ReturnAddress1 = Injector::GetBranchDestination(address + 0x7).as_int();
            tooltipAndButtonProc7ReturnAddress1 = address + 0x07 + get_branch_destination_offset(cast(void*)(address + 0x07), 4); // Placeholder

            // mov	edi, dword ptr [rsp+22D0h+var_2290]
            tooltipAndButtonProc7ReturnAddress2 = address + 0x24;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc7V133));
            writeln("JMP for tooltipAndButtonProc7Injector (v1_33_3_0) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc7Injector = true;
        }
        break;
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
        // inc ebx
        BytePattern.tempInstance().findPattern("FF C3 3B 5D 60 7D 1D E9 7D F7 FF FF E8");
        if (BytePattern.tempInstance().hasSize(1, "カウントアップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jmp loc_xxxxx
            // tooltipAndButtonProc7ReturnAddress1 = Injector::GetBranchDestination(address + 0x7).as_int();
            tooltipAndButtonProc7ReturnAddress1 = address + 0x07 + get_branch_destination_offset(cast(void*)(address + 0x07), 4); // Placeholder

            // mov	edi, dword ptr [rbp+6E0h+38h]
            tooltipAndButtonProc7ReturnAddress2 = address + 0x24;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc7));
            writeln("JMP for tooltipAndButtonProc7Injector created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc7Injector = true;
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
        // inc edx
        BytePattern.tempInstance().findPattern("FF C3 3B 5D 60 7D 1D E9 89 F7 FF FF E8");
        if (BytePattern.tempInstance().hasSize(1, "カウントアップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // tooltipAndButtonProc7ReturnAddress1 = Injector::GetBranchDestination(address + 0x7).as_int();
            tooltipAndButtonProc7ReturnAddress1 = address + 0x07 + get_branch_destination_offset(cast(void*)(address + 0x07), 4); // Placeholder
            tooltipAndButtonProc7ReturnAddress2 = address + 0x24;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)tooltipAndButtonProc7));
            writeln("JMP for tooltipAndButtonProc7Injector (v1_29-31) created.");
        }
        else {
            e.unmatchdTooltipAndButtonProc7Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc7Injector = true;
    }

    return e;
}
