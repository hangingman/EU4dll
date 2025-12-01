module plugin.localization.heir_name;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため
import plugin.misc; // get_branch_destination_offset を使用するため
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import std.logger;
import std.logger;
import std.stdio; // writeln を使用するため

DllError localizationProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_4_0: {
        // or      r9, 0FFFFFFFFFFFFFFFFh
        BytePattern.tempInstance().findPattern("49 83 C9 FF 45 33 C0 48 8B D0 49 8B CC E8 0B 1F");
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3));
            writeln("JMP for localizationProc3Injector (v1_29_4_0) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0: {
        string pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 D3 58 DC FF"; // Default pattern for these versions
        // FIXME: C++版のgoto JMPのようなパターンマッチングをD言語で再現する
        // 現状は一番上のパターンで固定
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3V130));
            writeln("JMP for localizationProc3Injector (v1_31_X) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0: {
        string pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 D3 9C DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3V130));
            writeln("JMP for localizationProc3Injector (v1_30_5_0) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_4_0: {
        string pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 F3 A1 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3V130));
            writeln("JMP for localizationProc3Injector (v1_30_4_0) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_3_0: {
        string pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 53 A1 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3V130));
            writeln("JMP for localizationProc3Injector (v1_30_3_0) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        string pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 43 A1 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3V130));
            writeln("JMP for localizationProc3Injector (v1_30_2_0) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        string pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 A3 A1 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc3V130));
            writeln("JMP for localizationProc3Injector (v1_30_1_0) created.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    default: {
        log(LogLevel.error, "MDEATH_HEIR_SUCCEEDS heir nameを逆転させる [NG]");
        e.versionLocalizationProc3Injector = true;
        break;
    }
    }

    return e;
}

DllError localizationProc4Injector(RunOptions options) {
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_4_0: {
        // or      r9, 0FFFFFFFFFFFFFFFFh
        BytePattern.tempInstance().findPattern("49 83 C9 FF 45 33 C0 48 8B D0 49 8B CC E8 B8 1E");
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4));
            writeln("JMP for localizationProc4Injector (v1_29_4_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1: {
        offset = 0x3C;
        pattern = "48 8B D8 48 8B 8E 70 19 00 00 48 89 8D A0 00 00 00 45 33 C9 45 33 C0 33 D2 48 8D 8D A0 00 00 00 E8 ? ? ? ? 4C 8B C8 48 89 7C 24 38 48 89 5C 24 28";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_33_X) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_6_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 D8 5D DC FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_31_6_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_5_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 88 5E DC FF"; // 1.31.5.2
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_31_5_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_31_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 88 7B DC FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_31_4_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_31_3_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 08 63 DC FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_31_3_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_31_2_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 F8 5B DC FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_31_2_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_30_5_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 95 9E DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_30_5_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_30_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 ? A1 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_30_4_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_30_3_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 F6 A0 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_30_3_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_30_2_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 E6 A0 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_30_2_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }

    case EU4Ver.v1_30_1_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 49 8B CF E8 46 A1 DD FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "MDEATH_REGENCY_RULE heir nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc4ReturnAddress = address + 0x12;

            // call {xxxxx} std::basic_string<char>#appendをフック。直接はバイナリパターンが多すぎでフックできなかった
            localizationProc1CallAddress2 = address + 0x0D + get_branch_destination_offset(cast(void*)(address + 0x0D), 4); // 仮のアドレス

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc4V130));
            writeln("JMP for localizationProc4Injector (v1_30_1_0) created.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }
    default: {
        log(LogLevel.error, "MDEATH_REGENCY_RULE heir nameを逆転させる [NG]");
        e.versionLocalizationProc4Injector = true;
        break;
    }
    }

    return e;
}
