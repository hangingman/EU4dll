module plugin.localization.date_fmt;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため
import plugin.misc; // get_branch_destination_offset を使用するため
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import std.stdio; // writeln を使用するため

DllError localizationProc6Injector(RunOptions options) {
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0: {
        /* 処理は不要になった。tmm_l_english.ymlのLONG_EU3_DATE_STRINGで代用される*/
        break;
    }
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0: {
        pattern = "4C 8D 05 ? ? ? ? 48 8D 55 DF 48 8D 4D BF E8 ? ? ? ? 90";
        offset = 0x26;
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_32_0_1) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_5_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 8F 74 A6"; // 1.31.5.2
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_31_5_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_4_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 3F AD A6";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_31_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_3_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 CF AD A6";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_31_3_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_2_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 DF 9C A6";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_31_2_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 ? ? AD";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_30_X) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 AF 7B AD";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_30_2_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 0F 7B AD";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_30_1_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CE E8 4F FA B4 FF";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M, Y → Y年M")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc6));
            writeln("JMP for localizationProc6Injector (v1_29_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc6Injector = true; // 削除
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("M, Y → Y年M [NG]");
        // e.versionLocalizationProc6Injector = true; // 削除
        break;
    }
    }

    return e;
}

DllError localizationProc7Injector(RunOptions options) {
    DllError e;
    string pattern;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0: {
        // 処理は不要になった
        break;
    }
    case EU4Ver.v1_30_5_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 05 61 B1 FF";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            localizationProc7CallAddress1 = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // 仮のアドレス
            localizationProc7CallAddress2 = address + 0x20 + get_branch_destination_offset(cast(void*)(address + 0x20), 4); // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc7));
            writeln("JMP for localizationProc7Injector (v1_30_5_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc7Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 ? 6B";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            localizationProc7CallAddress1 = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // 仮のアドレス
            localizationProc7CallAddress2 = address + 0x20 + get_branch_destination_offset(cast(void*)(address + 0x20), 4); // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc7));
            writeln("JMP for localizationProc7Injector (v1_30_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc7Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 45 6B";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            localizationProc7CallAddress1 = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // 仮のアドレス
            localizationProc7CallAddress2 = address + 0x20 + get_branch_destination_offset(cast(void*)(address + 0x20), 4); // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc7));
            writeln("JMP for localizationProc7Injector (v1_30_2_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc7Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 65 6A";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            localizationProc7CallAddress1 = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // 仮のアドレス
            localizationProc7CallAddress2 = address + 0x20 + get_branch_destination_offset(cast(void*)(address + 0x20), 4); // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc7));
            writeln("JMP for localizationProc7Injector (v1_30_1_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc7Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 65 9D";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            localizationProc7CallAddress1 = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // 仮のアドレス
            localizationProc7CallAddress2 = address + 0x20 + get_branch_destination_offset(cast(void*)(address + 0x20), 4); // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc7));
            writeln("JMP for localizationProc7Injector (v1_29_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc7Injector = true; // 削除
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("D M, Y → Y年MD日 [NG]");
        // e.versionLocalizationProc7Injector = true; // 削除
        break;
    }
    }

    return e;
}

DllError localizationProc8Injector(RunOptions options) {
    DllError e;
    string pattern;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_30_5_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            generateCString = address + 0x11 + get_branch_destination_offset(cast(void*)(address + 0x11), 4); // 仮のアドレス
            concatCString = address + 0x23 + get_branch_destination_offset(cast(void*)(address + 0x23), 4); // 仮のアドレス
            concat2CString = address + 0x33 + get_branch_destination_offset(cast(void*)(address + 0x33), 4); // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc8));
            writeln("JMP for localizationProc8Injector (v1_33_X) created.");
        }
        else {
            // e.unmatchdLocalizationProc8Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 ? E2";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            generateCString = address + 0x11 + get_branch_destination_offset(cast(void*)(address + 0x11), 4); // 仮のアドレス
            concatCString = address + 0x23 + get_branch_destination_offset(cast(void*)(address + 0x23), 4); // 仮のアドレス
            concat2CString = address + 0x33 + get_branch_destination_offset(cast(void*)(address + 0x33), 4); // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc8));
            writeln("JMP for localizationProc8Injector (v1_30_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc8Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 61 E2";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            generateCString = address + 0x11 + get_branch_destination_offset(cast(void*)(address + 0x11), 4); // 仮のアドレス
            concatCString = address + 0x23 + get_branch_destination_offset(cast(void*)(address + 0x23), 4); // 仮のアドレス
            concat2CString = address + 0x33 + get_branch_destination_offset(cast(void*)(address + 0x33), 4); // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc8));
            writeln("JMP for localizationProc8Injector (v1_30_2_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc8Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 81 E1";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            generateCString = address + 0x11 + get_branch_destination_offset(cast(void*)(address + 0x11), 4); // 仮のアドレス
            concatCString = address + 0x23 + get_branch_destination_offset(cast(void*)(address + 0x23), 4); // 仮のアドレス
            concat2CString = address + 0x33 + get_branch_destination_offset(cast(void*)(address + 0x33), 4); // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc8));
            writeln("JMP for localizationProc8Injector (v1_30_1_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc8Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 31 02";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            generateCString = address + 0x11 + get_branch_destination_offset(cast(void*)(address + 0x11), 4); // 仮のアドレス
            concatCString = address + 0x23 + get_branch_destination_offset(cast(void*)(address + 0x23), 4); // 仮のアドレス
            concat2CString = address + 0x33 + get_branch_destination_offset(cast(void*)(address + 0x33), 4); // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc8));
            writeln("JMP for localizationProc8Injector (v1_29_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc8Injector = true; // 削除
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("M Y → Y年M [NG]");
        // e.versionLocalizationProc8Injector = true; // 削除
        break;
    }
    }

    return e;
}
