module plugin.file_save;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions

extern(C) {
    void fileSaveProc1();
    void fileSaveProc2();
    void fileSaveProc3();
    void fileSaveProc3V130();
    void fileSaveProc3V1316();
    void fileSaveProc4();
    void fileSaveProc5();
    void fileSaveProc5V130();
    void fileSaveProc5V1316();
    void fileSaveProc6();
    void fileSaveProc6V130();
    void fileSaveProc7();
}

size_t fileSaveProc1ReturnAddress;
size_t fileSaveProc2ReturnAddress;
size_t fileSaveProc2CallAddress;
size_t fileSaveProc3ReturnAddress;
size_t fileSaveProc3CallAddress;
size_t fileSaveProc3CallAddress2;
size_t fileSaveProc4ReturnAddress;
size_t fileSaveProc4CallAddress;
size_t fileSaveProc4MarkerAddress;
size_t fileSaveProc5ReturnAddress;
size_t fileSaveProc5CallAddress;
size_t fileSaveProc5MarkerAddress;
size_t fileSaveProc6ReturnAddress;
size_t fileSaveProc6CallAddress;
size_t fileSaveProc6MarkerAddress;
size_t fileSaveProc7ReturnAddress;
size_t fileSaveProc7CallAddress;

// Helper functions (placeholders for now, need actual implementation or import)
// In C++ these are imported from escape_tool.h
extern(C) void escapedStrToUtf8() { writeln("Dummy escapedStrToUtf8 called"); }
extern(C) void utf8ToEscapedStr() { writeln("Dummy utf8ToEscapedStr called"); }
extern(C) void utf8ToEscapedStr2() { writeln("Dummy utf8ToEscapedStr2 called"); }


DllError fileSaveProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
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
        // mov     eax, [rcx+10h]
        BytePattern.tempInstance().findPattern("8B 41 10 85 C0 0F 84 31 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ファイル名を安全にしている場所を短絡する")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // fileSaveProc1ReturnAddress = Injector::GetBranchDestination(address + 0x5).as_int();
            fileSaveProc1ReturnAddress = address + 0x06; // Placeholder

            // Injector::MakeJMP(address, fileSaveProc1, true);
            writeln("Dummy JMP for fileSaveProc1Injector called.");
        }
        else {
            e.unmatchdFileSaveProc1Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc1Injector = true;
    }

    return e;
}

DllError fileSaveProc2Injector(RunOptions options) {
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        // mov     [rbp+57h+var_90], 0FFFFFFFFFFFFFFFEh
        pattern = "48 C7 45 C7 FE FF FF FF 48 89 9C 24 F0 00 00 00 48 8B F9 33 DB";
        offset = 0x54;
        break;
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
        pattern = "48 8D 05 ? ? ? FF 48 3B D0 75 06 48 8D 41 30 EB 02 FF D2 48 83 78 18 10 72";
        break;
    case EU4Ver.v1_30_5_0:
        pattern = "48 8D 05 51 D1 B3 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_30_4_0:
        pattern = "48 8D 05 ? ? B4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
        pattern = "48 8D 05 B1 4B B4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_30_1_0:
        pattern = "48 8D 05 91 4E B4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_29_4_0:
        pattern = "48 8D 05 91 FB A4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_29_3_0:
        pattern = "48 8D 05 11 92 A5 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_29_2_0:
        // lea     rax, sub_xxxxx ここしか取れなかった...
        pattern = "48 8D 05 01 A9 A5 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    default:
        e.versionFileSaveProc2Injector = true;
        return e;
    }

    BytePattern.tempInstance().findPattern(pattern);
    if (BytePattern.tempInstance().hasSize(1, "ファイル名をUTF-8に変換して保存できるようにする")) {
        size_t address = BytePattern.tempInstance().getFirst().address + offset;

        fileSaveProc2CallAddress = cast(size_t)&escapedStrToUtf8;

        // jnz     short loc_xxxxx
        fileSaveProc2ReturnAddress = address + 0x14 + 0x1B;

        // cmp word ptr [rax+18h], 10h
        // Injector::MakeJMP(address + 0x14, fileSaveProc2, true);
        writeln("Dummy JMP for fileSaveProc2Injector called.");
    }
    else {
        e.unmatchdFileSaveProc2Injector = true;
    }

    return e;
}

DllError fileSaveProc3Injector(RunOptions options) {
    DllError e;
    switch (options.eu4Version) {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_4_0:
        //  jmp     short loc_xxxxx
        BytePattern.tempInstance().findPattern("EB 6E 48 8D 15 ? ? ? ? FF 90 98 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする")) {
            //  lea     rdx, aSave_game_titl ; "save_game_title"
            size_t address = BytePattern.tempInstance().getFirst().address + 0x2;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call sub_xxxxx
            fileSaveProc3ReturnAddress = address + 0x1A;

            // Injector::MakeJMP(address, fileSaveProc3, true);
            writeln("Dummy JMP for fileSaveProc3Injector called.");
        }
        else {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
        //  jmp     short loc_xxxxx
        BytePattern.tempInstance().findPattern("EB 6E 48 8D 15 ? ? ? ? FF 90 98 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする")) {
            //  lea     rdx, aSave_game_titl ; "save_game_title"
            size_t address = BytePattern.tempInstance().getFirst().address + 0x2;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call sub_xxxxx
            fileSaveProc3ReturnAddress = address + 0x1A;

            // Injector::MakeJMP(address, fileSaveProc3V130, true);
            writeln("Dummy JMP for fileSaveProc3Injector (v1_30_plus) called.");
        }
        else {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        BytePattern.tempInstance().findPattern("45 33 C0 48 8D 93 80 05 00 00 49 8B CE");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする")) {
            //  xor     r8d, r8d
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call {xxxxx}
            // fileSaveProc3CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            fileSaveProc3CallAddress2 = address + 0x0E; // Placeholder

            // test rsi,rsi
            fileSaveProc3ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, fileSaveProc3V1316, true);
            writeln("Dummy JMP for fileSaveProc3Injector (v1_31_6_plus) called.");
        }
        else {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc3Injector = true;
    }

    return e;
}

DllError fileSaveProc4Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
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
        // lea     r8, [rbp+0]
        BytePattern.tempInstance().findPattern("4C 8D 45 00 48 8D 15 ? ? ? ? 48 8D 4C 24 70 E8 ? ? ? ? 90");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする1")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc4CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc4MarkerAddress = Injector::GetBranchDestination(address + 4).as_int();
            fileSaveProc4MarkerAddress = address + 0x05; // Placeholder

            // call sub_xxxxx
            fileSaveProc4ReturnAddress = address + 0x10;

            // Injector::MakeJMP(address, fileSaveProc4, true);
            writeln("Dummy JMP for fileSaveProc4Injector called.");
        }
        else {
            e.unmatchdFileSaveProc4Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc4Injector = true;
    }

    return e;
}

DllError fileSaveProc5Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     r8, [r14+598h]
        BytePattern.tempInstance().findPattern("4D 8D 86 98 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 50");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x08; // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, fileSaveProc5, true);
            writeln("Dummy JMP for fileSaveProc5Injector called.");
        }
        else {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
        // lea     r8, [r14+5C0h]
        BytePattern.tempInstance().findPattern("4D 8D 86 C0 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 50");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x08; // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, fileSaveProc5V130, true);
            writeln("Dummy JMP for fileSaveProc5Injector (v1_30_plus) called.");
        }
        else {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        // lea     r8, [r14+5C0h]
        BytePattern.tempInstance().findPattern("4D 8D 86 C0 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 60");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x08; // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, fileSaveProc5V1316, true);
            writeln("Dummy JMP for fileSaveProc5Injector (v1_31_6_plus) called.");
        }
        else {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc5Injector = true;
    }

    return e;
}

DllError fileSaveProc6Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     r8, [rbp+380h]
        BytePattern.tempInstance().findPattern("4C 8D 85 80 03 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 30");
        if (BytePattern.tempInstance().hasSize(1, "スタート画面でのコンティニューのツールチップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc6CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea r8, {aZy}
            // fileSaveProc6MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc6MarkerAddress = address + 0x08; // Placeholder

            // call sub_xxxxx
            fileSaveProc6ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, fileSaveProc6, true);
            writeln("Dummy JMP for fileSaveProc6Injector called.");
        }
        else {
            e.unmatchdFileSaveProc6Injector = true;
        }
        break;
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // lea     r8, [rbp+730h+var_3A0]
        BytePattern.tempInstance().findPattern("4C 8D 85 90 03 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 30");
        if (BytePattern.tempInstance().hasSize(1, "スタート画面でのコンティニューのツールチップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc6CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea r8, {aZy}
            // fileSaveProc6MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc6MarkerAddress = address + 0x08; // Placeholder

            // call sub_xxxxx
            fileSaveProc6ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, fileSaveProc6V130, true);
            writeln("Dummy JMP for fileSaveProc6Injector (v1_30_plus) called.");
        }
        else {
            e.unmatchdFileSaveProc6Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc6Injector = true;
    }

    return e;
}

DllError fileSaveProc7Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     rcx, [rbx+0C8h]
        BytePattern.tempInstance().findPattern("48 8D 8B C8 00 00 00 48 8B 01 48 8D 54 24 28");
        if (BytePattern.tempInstance().hasSize(1, "セーブダイアログでのインプットテキストエリア")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc7CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // call    qword ptr [rax+80h]
            fileSaveProc7ReturnAddress = address + 0xF;

            // Injector::MakeJMP(address, fileSaveProc7, true);
            writeln("Dummy JMP for fileSaveProc7Injector called.");
        }
        else {
            e.unmatchdFileSaveProc7Injector = true;
        }
        break;
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // lea     rcx, [rbx+0C8h]
        size_t address;

        // epic
        BytePattern.tempInstance().findPattern("48 8D 8B C8 00 00 00 48 8B 01 48 8D 54 24 28");
        if (BytePattern.tempInstance().hasSize(1, "セーブダイアログでのインプットテキストエリア")) {
            address = BytePattern.tempInstance().getFirst().address;
        }
        // steam
        else if (BytePattern.tempInstance().hasSize(2, "セーブダイアログでのインプットテキストエリア")) {
            address = BytePattern.tempInstance().getSecond().address;
        }
        else {
            e.unmatchdFileSaveProc7Injector = true;
            break;
        }

        fileSaveProc7CallAddress = cast(size_t)&utf8ToEscapedStr2;

        // call    qword ptr [rax+80h]
        fileSaveProc7ReturnAddress = address + 0xF;

        // Injector::MakeJMP(address, fileSaveProc7, true);
        writeln("Dummy JMP for fileSaveProc7Injector (v1_30_plus) called.");

        break;
    default:
        e.versionFileSaveProc7Injector = true;
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    /* UTF-8ファイルを列挙できない問題は解決された */
    result = result | fileSaveProc1Injector(options);
    result = result | fileSaveProc2Injector(options);
    result = result | fileSaveProc3Injector(options);
    // これは使われなくなった？
    //result |= fileSaveProc4Injector(options);
    result = result | fileSaveProc5Injector(options);
    result = result | fileSaveProc6Injector(options);
    result = result | fileSaveProc7Injector(options);

    return result;
}
