module plugin.file_save;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

extern (C)
{
    void* fileSaveProc1() { return null; }
    void* fileSaveProc2() { return null; }
    void* fileSaveProc3() { return null; }
    void* fileSaveProc3V130() { return null; }
    void* fileSaveProc3V1316() { return null; }
    void* fileSaveProc4() { return null; }
    void* fileSaveProc5() { return null; }
    void* fileSaveProc5V130() { return null; }
    void* fileSaveProc5V1316() { return null; }
    void* fileSaveProc6() { return null; }
    void* fileSaveProc6V130() { return null; }
    void* fileSaveProc7() { return null; }
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
extern (C) void escapedStrToUtf8()
{
    writeln("Dummy escapedStrToUtf8 called");
}

extern (C) void utf8ToEscapedStr()
{
    writeln("Dummy utf8ToEscapedStr called");
}

extern (C) void utf8ToEscapedStr2()
{
    writeln("Dummy utf8ToEscapedStr2 called");
}

DllError fileSaveProc1Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
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
        BytePattern.tempInstance()
            .findPattern("8B 41 10 85 C0 0F 84 31 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ファイル名を安全にしている場所を短絡する"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // fileSaveProc1ReturnAddress = Injector::GetBranchDestination(address + 0x5).as_int();
            fileSaveProc1ReturnAddress = address + 0x05 + get_branch_destination_offset(
                cast(void*)(address + 0x05), 4); // Placeholder

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc1));
            writeln("JMP for fileSaveProc1Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc1Injector = true; // 修正: Proc2InjectorではなくProc1Injectorのエラーフラグを立てる
        }
        break;
    default:
        e.versionFileSaveProc1Injector = true;
    }

    return e;
}

DllError fileSaveProc2Injector(RunOptions options)
{
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version)
    {
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
    if (BytePattern.tempInstance().hasSize(1, "ファイル名をUTF-8に変換して保存できるようにする"))
    {
        size_t address = BytePattern.tempInstance().getFirst().address + offset;

        fileSaveProc2CallAddress = cast(size_t)&escapedStrToUtf8;

        // jnz     short loc_xxxxx
        fileSaveProc2ReturnAddress = address + 0x14 + 0x1B;

        PatchManager.instance().addPatch(cast(void*)(address + 0x14), makeJmp(
                cast(void*)(address + 0x14), cast(void*) fileSaveProc2));
        writeln("JMP for fileSaveProc2Injector created.");
    }
    else
    {
        e.unmatchdFileSaveProc2Injector = true;
    }

    return e;
}

DllError fileSaveProc3Injector(RunOptions options)
{
    DllError e;
    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_4_0:
        //  jmp     short loc_xxxxx
        BytePattern.tempInstance().findPattern("EB 6E 48 8D 15 ? ? ? ? FF 90 98 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする"))
        {
            //  lea     rdx, aSave_game_titl ; "save_game_title"
            size_t address = BytePattern.tempInstance().getFirst().address + 0x2;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call sub_xxxxx
            fileSaveProc3ReturnAddress = address + 0x1A;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc3));
            writeln("JMP for fileSaveProc3Injector created.");
        }
        else
        {
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
        BytePattern.tempInstance()
            .findPattern("EB 6E 48 8D 15 ? ? ? ? FF 90 98 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする"))
        {
            //  lea     rdx, aSave_game_titl ; "save_game_title"
            size_t address = BytePattern.tempInstance().getFirst().address + 0x2;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call sub_xxxxx
            fileSaveProc3ReturnAddress = address + 0x1A;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc3V130));
            writeln("JMP for fileSaveProc3Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        BytePattern.tempInstance().findPattern("45 33 C0 48 8D 93 80 05 00 00 49 8B CE");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする"))
        {
            //  xor     r8d, r8d
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call {xxxxx}
            // fileSaveProc3CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            fileSaveProc3CallAddress2 = address + 0x0D + get_branch_destination_offset(
                cast(void*)(address + 0x0D), 4); // Placeholder

            // test rsi,rsi
            fileSaveProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc3V1316));
            writeln("JMP for fileSaveProc3Injector (v1_31_6_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc3Injector = true;
    }

    return e;
}

DllError fileSaveProc4Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
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
        BytePattern.tempInstance()
            .findPattern("4C 8D 45 00 48 8D 15 ? ? ? ? 48 8D 4C 24 70 E8 ? ? ? ? 90");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする1"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc4CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc4MarkerAddress = Injector::GetBranchDestination(address + 4).as_int();
            fileSaveProc4MarkerAddress = address + 0x04 + get_branch_destination_offset(
                cast(void*)(address + 0x04), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc4ReturnAddress = address + 0x10;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc4));
            writeln("JMP for fileSaveProc4Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc4Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc4Injector = true;
    }

    return e;
}

DllError fileSaveProc5Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     r8, [r14+598h]
        BytePattern.tempInstance()
            .findPattern("4D 8D 86 98 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 50");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc5));
            writeln("JMP for fileSaveProc5Injector created.");
        }
        else
        {
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
        BytePattern.tempInstance()
            .findPattern("4D 8D 86 C0 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 50");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc5V130));
            writeln("JMP for fileSaveProc5Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        // lea     r8, [r14+5C0h]
        BytePattern.tempInstance()
            .findPattern("4D 8D 86 C0 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 60");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc5V1316));
            writeln("JMP for fileSaveProc5Injector (v1_31_6_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc5Injector = true;
    }

    return e;
}

DllError fileSaveProc6Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     r8, [rbp+380h]
        BytePattern.tempInstance()
            .findPattern("4C 8D 85 80 03 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 30");
        if (BytePattern.tempInstance().hasSize(1, "スタート画面でのコンティニューのツールチップ"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc6CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea r8, {aZy}
            // fileSaveProc6MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc6MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc6));
            writeln("JMP for fileSaveProc6Injector created.");
        }
        else
        {
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
        BytePattern.tempInstance()
            .findPattern("4C 8D 85 90 03 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 30");
        if (BytePattern.tempInstance().hasSize(1, "スタート画面でのコンティニューのツールチップ"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc6CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea r8, {aZy}
            // fileSaveProc6MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc6MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc6V130));
            writeln("JMP for fileSaveProc6Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc6Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc6Injector = true;
    }

    return e;
}

DllError fileSaveProc7Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     rcx, [rbx+0C8h]
        BytePattern.tempInstance()
            .findPattern("48 8D 8B C8 00 00 00 48 8B 01 48 8D 54 24 28");
        if (BytePattern.tempInstance().hasSize(1, "セーブダイアログでのインプットテキストエリア"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc7CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // call    qword ptr [rax+80h]
            fileSaveProc7ReturnAddress = address + 0xF;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc7));
            writeln("JMP for fileSaveProc7Injector created.");
        }
        else
        {
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
        if (BytePattern.tempInstance().hasSize(1, "セーブダイアログでのインプットテキストエリア"))
        {
            address = BytePattern.tempInstance().getFirst().address;
        }
        // steam
        else if (BytePattern.tempInstance().hasSize(2, "セーブダイアログでのインプットテキストエリア"))
        {
            address = BytePattern.tempInstance().getSecond().address;
        }
        else
        {
            e.unmatchdFileSaveProc7Injector = true;
            break;
        }

        fileSaveProc7CallAddress = cast(size_t)&utf8ToEscapedStr2;

        // call    qword ptr [rax+80h]
        fileSaveProc7ReturnAddress = address + 0xF;

        PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                void*) fileSaveProc7));
        writeln("JMP for fileSaveProc7Injector (v1_30_plus) created.");

        break;
    default:
        e.versionFileSaveProc7Injector = true;
    }

    return e;
}

DllError init(EU4Ver eu4Version)
{
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
