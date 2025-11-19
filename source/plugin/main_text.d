module plugin.main_text;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート

extern(C) {
    void mainTextProc1();
    void mainTextProc2();
    void mainTextProc2_v131();
    void mainTextProc3();
    void mainTextProc4();
}

size_t mainTextProc1ReturnAddress;
size_t mainTextProc2ReturnAddress;
size_t mainTextProc2BufferAddress;
size_t mainTextProc3ReturnAddress1;
size_t mainTextProc3ReturnAddress2;
size_t mainTextProc4ReturnAddress;

DllError mainTextProc1Injector(RunOptions options) {
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
    case EU4Ver.v1_33_3_0: {
        // movsxd rax, edi
        BytePattern.tempInstance().findPattern("48 63 C7 0F B6 04 18 F3 41 0F 10 9F 48 08 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ２の文字取得修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // movss dword ptr [rpb+108h], xmm3
            mainTextProc1ReturnAddress = address + 0x1B;

            // Injector::MakeJMP(address, cast(size_t)mainTextProc1, true);
            writeln("Dummy JMP for mainTextProc1Injector called.");
        }
        else {
            e.unmatchdMainTextProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionMainTextProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError mainTextProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_33_3_0: {
        // movsxd rdx, edi
        BytePattern.tempInstance().findPattern("48 63 D7 49 63 CE 4C 8B 55 80");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１のカウント処理修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // cmp byte ptr [rbp+750h+arg_50],0
            mainTextProc2ReturnAddress = address + 0x1D;

            // lea r9, {unk_XXXXX}
            // mainTextProc2BufferAddress = Injector::GetBranchDestination(address + 0x0F).as_int();
            mainTextProc2BufferAddress = address + 0x10; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)mainTextProc2_v131, true);
            writeln("Dummy JMP for mainTextProc2Injector (v131) called.");
        }
        else {
            e.unmatchdMainTextProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_29_1_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0: {
        // movsxd rdx, edi
        BytePattern.tempInstance().findPattern("48 63 D7 49 63 CE 4C 8B 54 24 78");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１のカウント処理修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // cmp byte ptr [rbp+7B0h],0
            mainTextProc2ReturnAddress = address + 0x1E;

            // lea r9, {unk_XXXXX}
            // mainTextProc2BufferAddress = Injector::GetBranchDestination(address + 0x10).as_int();
            mainTextProc2BufferAddress = address + 0x11; // 仮のアドレス

            // Injector::MakeJMP(address, cast(size_t)mainTextProc2, true);
            writeln("Dummy JMP for mainTextProc2Injector called.");
        }
        else {
            e.unmatchdMainTextProc2Injector = true;
        }
        break;
    }
    default: {
        e.versionMainTextProc2Injector = true;
        break;
    }
    }

    return e;
}

DllError mainTextProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1: {
        // cmp cs:byte_xxxxx, 0
        BytePattern.tempInstance().findPattern("80 3D ? ? ? ? 00 0F 84 9A 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理の戻り先２取得")) {
            mainTextProc3ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdMainTextProc3Injector = true;
        }

        // cmp word ptr [rcx+6],0
        BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 16 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理を修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // cvtdq2ps xmm1,xmm1
            mainTextProc3ReturnAddress1 = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mainTextProc3, true);
            writeln("Dummy JMP for mainTextProc3Injector (v133) called.");
        }
        else {
            e.unmatchdMainTextProc3Injector = true;
        }
        break;
    }

    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0: {
        // cmp cs:byte_xxxxx, 0
        BytePattern.tempInstance().findPattern("80 3D ? ? ? ? 00 0F 84 97 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理の戻り先２取得")) {
            mainTextProc3ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdMainTextProc3Injector = true;
        }

        // cmp word ptr [rcx+6],0
        BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 16 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理を修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // cvtdq2ps xmm1,xmm1
            mainTextProc3ReturnAddress1 = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mainTextProc3, true);
            writeln("Dummy JMP for mainTextProc3Injector (v131) called.");
        }
        else {
            e.unmatchdMainTextProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_29_1_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0: {
        // cmp cs:byte_xxxxx, 0
        BytePattern.tempInstance().findPattern("80 3D ? ? ? ? 00 0F 84 97 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理の戻り先２取得")) {
            mainTextProc3ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdMainTextProc3Injector = true;
        }

        // cmp word ptr [rcx+6],0
        BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 15 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理を修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // cvtdq2ps xmm1,xmm1
            mainTextProc3ReturnAddress1 = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mainTextProc3, true);
            writeln("Dummy JMP for mainTextProc3Injector called.");
        }
        else {
            e.unmatchdMainTextProc3Injector = true;
        }
        break;
    }
    default: {
        e.versionMainTextProc3Injector = true;
        break;
    }
    }

    return e;
}

DllError mainTextProc4Injector(RunOptions options) {
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
    case EU4Ver.v1_33_3_0: {
        // movzx eax, byte ptr [rdx+r10]
        BytePattern.tempInstance().findPattern("42 0F B6 04 12 49 8B 0C C7");
        if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の文字取得修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz loc_xxxxx
            mainTextProc4ReturnAddress = address + 0x10;

            // Injector::MakeJMP(address, cast(size_t)mainTextProc4, true);
            writeln("Dummy JMP for mainTextProc4Injector called.");
        }
        else {
            e.unmatchdMainTextProc4Injector = true;
        }
        break;
    }
    default: {
        e.versionMainTextProc4Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | mainTextProc1Injector(options);
    result = result | mainTextProc2Injector(options);
    result = result | mainTextProc3Injector(options);
    result = result | mainTextProc4Injector(options);

    return result;
}
