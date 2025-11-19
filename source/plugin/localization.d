module plugin.localization;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート

extern(C) {
    void localizationProc2();
    void localizationProc3();
    void localizationProc3V130();
    void localizationProc4();
    void localizationProc4V130();
    void localizationProc5();
    void localizationProc5V131();
    void localizationProc6();
    void localizationProc7();
    void localizationProc7V131();
    void localizationProc8();
}

size_t localizationProc1CallAddress1;
size_t localizationProc1CallAddress2;
size_t localizationProc2ReturnAddress;
size_t localizationProc3ReturnAddress;
size_t localizationProc4ReturnAddress;
size_t localizationProc5ReturnAddress;
size_t localizationProc6ReturnAddress;
size_t localizationProc7ReturnAddress;
size_t localizationProc8ReturnAddress;

size_t localizationProc7CallAddress1;
size_t localizationProc7CallAddress2;

size_t generateCString;
size_t concatCString;
size_t concat2CString;

size_t year;
size_t month;
size_t day;

// ParadoxTextObjectに相当する構造体（仮）
// 実際の定義はplugin_64.hにあるはずだが、ここでは簡易的に定義
struct ParadoxTextObject {
    struct Text {
        char[11] text;
    } t;
    size_t len;
    size_t len2;
}

DllError localizationProc1Injector(RunOptions options){
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // mov     [rsp+arg_10], rbx
        BytePattern.tempInstance().findPattern("48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0");
        if (BytePattern.tempInstance().hasSize(1, "std::basic_string<char>#insertをフック")) {
            localizationProc1CallAddress1 = BytePattern.tempInstance().getFirst().address;
            writeln("Dummy Hook for localizationProc1Injector called.");
        }
        else {
            e.unmatchdLocalizationProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionLocalizationProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError localizationProc2Injector(RunOptions options) {
    DllError e;

    // if (!options.reversingWordsBattleOfArea) return e; // FIXME: RunOptionsにreversingWordsBattleOfAreaがないためコメントアウト

    switch (options.eu4Version) {
    case EU4Ver.v1_29_4_0: {
        // nop
        BytePattern.tempInstance().findPattern("90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 13 70 EB FF");
        if (BytePattern.tempInstance().hasSize(1, "Battle of areaを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc2ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)localizationProc2, true);
            writeln("Dummy JMP for localizationProc2Injector (v1_29_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0: {
        // mov     rcx, [rdi+30h]
        BytePattern.tempInstance().findPattern("48 8B 4F 30 48 83 C1 10 48 8B 01");
        if (BytePattern.tempInstance().hasSize(2, "Battle of areaを逆転させる")) {
            // nop
            size_t address = BytePattern.tempInstance().getFirst().address(0x3B);

            // nop
            localizationProc2ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)localizationProc2, true);
            writeln("Dummy JMP for localizationProc2Injector (v1_30_X) called.");
        }
        else {
            e.unmatchdLocalizationProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // mov     rax, [rdi+30h]
        BytePattern.tempInstance().findPattern("48 8B 47 30 4C 8B 40 28 49 83 C0 10");
        if (BytePattern.tempInstance().hasSize(1, "Battle of areaを逆転させる")) {
            // nop
            size_t address = BytePattern.tempInstance().getFirst().address(0x1D);

            // nop
            localizationProc2ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)localizationProc2, true);
            writeln("Dummy JMP for localizationProc2Injector (v1_31_X) called.");
        }
        else {
            e.unmatchdLocalizationProc2Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("Battle of areaを逆転させる [NG]");
        e.versionLocalizationProc2njector = true;
        break;
    }
    }

    return e;
}


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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_29_4_0) called.");
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3V130, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_31_X) called.");
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3V130, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_30_5_0) called.");
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3V130, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_30_4_0) called.");
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3V130, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_30_3_0) called.");
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3V130, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_30_2_0) called.");
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc3V130, true);
            writeln("Dummy JMP for localizationProc3Injector (v1_30_1_0) called.");
        }
        else {
            e.unmatchdLocalizationProc3Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("MDEATH_HEIR_SUCCEEDS heir nameを逆転させる [NG]");
        e.versionLocalizationProc3njector = true;
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)wordOrderProc4, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_29_4_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_33_X) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_31_6_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_31_5_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_31_4_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_31_3_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_31_2_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_30_5_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_30_4_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_30_3_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_30_2_0) called.");
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
            // localizationProc1CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            localizationProc1CallAddress2 = address + 0x0E; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)localizationProc4V130, true);
            writeln("Dummy JMP for localizationProc4Injector (v1_30_1_0) called.");
        }
        else {
            e.unmatchdLocalizationProc4Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("MDEATH_REGENCY_RULE heir nameを逆転させる [NG]");
        e.versionLocalizationProc4Injector = true;
        break;
    }
    }

    return e;
}

DllError localizationProc5Injector(RunOptions options) {
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0: {
        pattern = "48 8B 4F 68 48 8B 01 FF 50 08 84 C0 74 5F 48 8B 07";
        offset = 0x40;
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5V131, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_33_X) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_5_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 73 81 76 FF"; // 1.31.5.2
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5V131, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_31_5_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 33 C0 76 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5V131, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_31_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_3_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 23 C1 76 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5V131, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_31_3_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_2_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 83 BA 76 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5V131, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_31_2_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }

    case EU4Ver.v1_30_5_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 ? FF 90 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_30_5_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 ? 1D 91 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_30_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_3_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 C7 1D 91 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_30_3_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 B7 1D 91 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_30_2_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 27 1D";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_30_1_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 27 41";			
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)localizationProc5, true);
            writeln("Dummy JMP for localizationProc5Injector (v1_29_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc5Injector = true;
        }
        break;
    }
    default: {
        e.versionLocalizationProc5Injector = true;
        BytePattern.tempInstance().debugOutput("nameを逆転させる [NG]");
        break;
    }
    }

    return e;
}

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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_32_0_1) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_31_5_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_31_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_31_3_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_31_2_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_30_X) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_30_2_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_30_1_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
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

            // Injector::MakeJMP(address, cast(size_t)localizationProc6, true);
            writeln("Dummy JMP for localizationProc6Injector (v1_29_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc6Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("M, Y → Y年M [NG]");
        e.versionLocalizationProc6Injector = true;
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

            // localizationProc7CallAddress1 = Injector::GetBranchDestination(address + 0xF).as_int();
            localizationProc7CallAddress1 = address + 0x10; // 仮のアドレス
            // localizationProc7CallAddress2 = Injector::GetBranchDestination(address + 0x20).as_int();
            localizationProc7CallAddress2 = address + 0x21; // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            // Injector::MakeJMP(address, cast(size_t)localizationProc7, true);
            writeln("Dummy JMP for localizationProc7Injector (v1_30_5_0) called.");
        }
        else {
            e.unmatchdLocalizationProc7Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 ? 6B";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // localizationProc7CallAddress1 = Injector::GetBranchDestination(address + 0xF).as_int();
            localizationProc7CallAddress1 = address + 0x10; // 仮のアドレス
            // localizationProc7CallAddress2 = Injector::GetBranchDestination(address + 0x20).as_int();
            localizationProc7CallAddress2 = address + 0x21; // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            // Injector::MakeJMP(address, cast(size_t)localizationProc7, true);
            writeln("Dummy JMP for localizationProc7Injector (v1_30_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc7Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 45 6B";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // localizationProc7CallAddress1 = Injector::GetBranchDestination(address + 0xF).as_int();
            localizationProc7CallAddress1 = address + 0x10; // 仮のアドレス
            // localizationProc7CallAddress2 = Injector::GetBranchDestination(address + 0x20).as_int();
            localizationProc7CallAddress2 = address + 0x21; // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            // Injector::MakeJMP(address, cast(size_t)localizationProc7, true);
            writeln("Dummy JMP for localizationProc7Injector (v1_30_2_0) called.");
        }
        else {
            e.unmatchdLocalizationProc7Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 65 6A";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // localizationProc7CallAddress1 = Injector::GetBranchDestination(address + 0xF).as_int();
            localizationProc7CallAddress1 = address + 0x10; // 仮のアドレス
            // localizationProc7CallAddress2 = Injector::GetBranchDestination(address + 0x20).as_int();
            localizationProc7CallAddress2 = address + 0x21; // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            // Injector::MakeJMP(address, cast(size_t)localizationProc7, true);
            writeln("Dummy JMP for localizationProc7Injector (v1_30_1_0) called.");
        }
        else {
            e.unmatchdLocalizationProc7Injector = true;
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "90 4C 8D 44 24 48 48 8D 54 24 28 48 8D 4D E8 E8 65 9D";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "D M, Y → Y年MD日")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // localizationProc7CallAddress1 = Injector::GetBranchDestination(address + 0xF).as_int();
            localizationProc7CallAddress1 = address + 0x10; // 仮のアドレス
            // localizationProc7CallAddress2 = Injector::GetBranchDestination(address + 0x20).as_int();
            localizationProc7CallAddress2 = address + 0x21; // 仮のアドレス

            // nop
            localizationProc7ReturnAddress = address + 0x5E;

            // Injector::MakeJMP(address, cast(size_t)localizationProc7, true);
            writeln("Dummy JMP for localizationProc7Injector (v1_29_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc7Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("D M, Y → Y年MD日 [NG]");
        e.versionLocalizationProc7Injector = true;
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

            // generateCString = Injector::GetBranchDestination(address + 0x11).as_int();
            generateCString = address + 0x12; // 仮のアドレス
            // concatCString = Injector::GetBranchDestination(address + 0x23).as_int();
            concatCString = address + 0x24; // 仮のアドレス
            // concat2CString = Injector::GetBranchDestination(address + 0x33).as_int();
            concat2CString = address + 0x34; // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            // Injector::MakeJMP(address, cast(size_t)localizationProc8, true);
            writeln("Dummy JMP for localizationProc8Injector (v1_33_X) called.");
        }
        else {
            e.unmatchdLocalizationProc8Injector = true;
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

            // generateCString = Injector::GetBranchDestination(address + 0x11).as_int();
            generateCString = address + 0x12; // 仮のアドレス
            // concatCString = Injector::GetBranchDestination(address + 0x23).as_int();
            concatCString = address + 0x24; // 仮のアドレス
            // concat2CString = Injector::GetBranchDestination(address + 0x33).as_int();
            concat2CString = address + 0x34; // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            // Injector::MakeJMP(address, cast(size_t)localizationProc8, true);
            writeln("Dummy JMP for localizationProc8Injector (v1_30_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc8Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 61 E2";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            // generateCString = Injector::GetBranchDestination(address + 0x11).as_int();
            generateCString = address + 0x12; // 仮のアドレス
            // concatCString = Injector::GetBranchDestination(address + 0x23).as_int();
            concatCString = address + 0x24; // 仮のアドレス
            // concat2CString = Injector::GetBranchDestination(address + 0x33).as_int();
            concat2CString = address + 0x34; // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            // Injector::MakeJMP(address, cast(size_t)localizationProc8, true);
            writeln("Dummy JMP for localizationProc8Injector (v1_30_2_0) called.");
        }
        else {
            e.unmatchdLocalizationProc8Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 81 E1";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            // generateCString = Injector::GetBranchDestination(address + 0x11).as_int();
            generateCString = address + 0x12; // 仮のアドレス
            // concatCString = Injector::GetBranchDestination(address + 0x23).as_int();
            concatCString = address + 0x24; // 仮のアドレス
            // concat2CString = Injector::GetBranchDestination(address + 0x33).as_int();
            concat2CString = address + 0x34; // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            // Injector::MakeJMP(address, cast(size_t)localizationProc8, true);
            writeln("Dummy JMP for localizationProc8Injector (v1_30_1_0) called.");
        }
        else {
            e.unmatchdLocalizationProc8Injector = true;
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "90 4C 8D 45 A7 48 8D 55 0F 48 8D 4D EF E8 31 02";
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "M Y → Y年M")) {
            // mov     r8d, 1
            size_t address = BytePattern.tempInstance().getFirst().address - 0x16;

            // generateCString = Injector::GetBranchDestination(address + 0x11).as_int();
            generateCString = address + 0x12; // 仮のアドレス
            // concatCString = Injector::GetBranchDestination(address + 0x23).as_int();
            concatCString = address + 0x24; // 仮のアドレス
            // concat2CString = Injector::GetBranchDestination(address + 0x33).as_int();
            concat2CString = address + 0x34; // 仮のアドレス

            // nop
            localizationProc8ReturnAddress = address + 0x38;

            // Injector::MakeJMP(address, cast(size_t)localizationProc8, true);
            writeln("Dummy JMP for localizationProc8Injector (v1_29_4_0) called.");
        }
        else {
            e.unmatchdLocalizationProc8Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("M Y → Y年M [NG]");
        e.versionLocalizationProc8Injector = true;
        break;
    }
    }

    return e;
}

DllError localizationProc9Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0: {
        BytePattern.tempInstance().findPattern("20 2D 20 00 4D 4F 4E 54 48 53 00 00");
        if (BytePattern.tempInstance().hasSize(1, "Replace space")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            // Injector::WriteMemory!ubyte(address+0, 0x20,true);
            // Injector::WriteMemory!ubyte(address+1, 0x2D, true);
            // Injector::WriteMemory!ubyte(address+2, 0x20, true);
            writeln("Dummy WriteMemory for localizationProc9Injector called.");
        }
        else {
            e.unmatchdLocalizationProc9Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("Replace space [NG]");
        e.versionLocalizationProc9Injector = true;
        break;
    }
    }

    return e;
}

ParadoxTextObject _year;
ParadoxTextObject _month;
ParadoxTextObject _day;

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    _day.t.text[0] = cast(char)0xE;
    _day.t.text[1] = '\0';
    _day.len = 1;
    _day.len2 = 0xF;

    _year.t.text[0] = cast(char)0xF;
    _year.t.text[1] = '\0';
    _year.len = 1;
    _year.len2 = 0xF;

    _month.t.text[0] = cast(char)7;
    _month.t.text[1] = '\0';
    _month.len = 1;
    _month.len2 = 0xF;
    
    year = cast(size_t) &_year;
    month = cast(size_t)&_month;
    day = cast(size_t)&_day;

    // 関数アドレス取得
    result = result | localizationProc1Injector(options);

    // Battle of areaを逆転させる
    // 確認方法）敵軍と戦い、結果のポップアップのタイトルを確認する
    result = result | localizationProc2Injector(options);

    // MDEATH_HEIR_SUCCEEDS heir nameを逆転させる
    //result = result | localizationProc3Injector(options);

    // MDEATH_REGENCY_RULE heir nameを逆転させる
    // ※localizationProc1CallAddress2のhookもこれで実行している
    result = result | localizationProc4Injector(options);

    // nameを逆転させる
    // 確認方法）sub modを入れた状態で日本の大名を選択する。大名の名前が逆転しているかを確認する
    result = result | localizationProc5Injector(options);

    // 年号の表示がM, YからY年M
    // 確認方法）オスマンで画面上部の停戦アラートのポップアップの年号を確認する
    result = result | localizationProc6Injector(options);

    // 年号の表示がD M, YからY年MD日になる
    // 確認方法）スタート画面のセーブデータの日付を見る
    result = result | localizationProc7Injector(options);

    // 年号の表示がM YからY年Mになる
    // 確認方法）外交官のポップアップを表示し、年号を確認する
    result = result | localizationProc8Injector(options);

    // スペースを変更
    //result = result | localizationProc9Injector(options);

    return result;
}
