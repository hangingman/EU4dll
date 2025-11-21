module plugin.tooltip_and_button;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

extern(C) {
    void tooltipAndButtonProc1();
    void tooltipAndButtonProc1V133();
    void tooltipAndButtonProc2();
    void tooltipAndButtonProc2V133();
    void tooltipAndButtonProc3();
    void tooltipAndButtonProc4();
    void tooltipAndButtonProc4V133();
    void tooltipAndButtonProc5();
    void tooltipAndButtonProc5V130();
    void tooltipAndButtonProc7();
    void tooltipAndButtonProc7V133();
}

size_t tooltipAndButtonProc1ReturnAddress;
size_t tooltipAndButtonProc1CallAddress;
size_t tooltipAndButtonProc2ReturnAddress;
size_t tooltipAndButtonProc3ReturnAddress;
size_t tooltipAndButtonProc4ReturnAddress1;
size_t tooltipAndButtonProc4ReturnAddress2;
size_t tooltipAndButtonProc5ReturnAddress1;
size_t tooltipAndButtonProc5ReturnAddress2;
size_t tooltipAndButtonProc7ReturnAddress1;
size_t tooltipAndButtonProc7ReturnAddress2;

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

DllError tooltipAndButtonProc6Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
        // inc edx
        BytePattern.tempInstance().findPattern("A7 52 2D 20 00 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "空白をノーブレークスペースに変換")) {
            PatchManager.instance().addPatch(BytePattern.tempInstance().getFirst().address + 3, [0xA0]);
            writeln("WriteMemory for tooltipAndButtonProc6Injector called.");
        }
        else {
            e.unmatchdTooltipAndButtonProc6Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc6Injector = true;
    }

    return e;
}

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

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | tooltipAndButtonProc1Injector(options);
    result = result | tooltipAndButtonProc2Injector(options);
    result = result | tooltipAndButtonProc3Injector(options);
    result = result | tooltipAndButtonProc4Injector(options);
    result = result | tooltipAndButtonProc5Injector(options);
    result = result | tooltipAndButtonProc6Injector(options);
    result = result | tooltipAndButtonProc7Injector(options);

    return result;
}
