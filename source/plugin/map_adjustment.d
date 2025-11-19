module plugin.map_adjustment;

import std.stdio;
import std.string; // toHexString
import core.stdc.string; // memcpy, strlen
import core.stdc.stdlib; // malloc, free
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
// FIXME: escape_tool.d を後で作成し、インポートする

extern(C) {
    void mapAdjustmentProc1();
    void mapAdjustmentProc2();
    void mapAdjustmentProc2V130();
    void mapAdjustmentProc3();
    void mapAdjustmentProc3V130();
    void mapAdjustmentProc4();
    void mapAdjustmentProc4V130();
    void mapAdjustmentProc5();
}

size_t mapAdjustmentProc1ReturnAddress;
size_t mapAdjustmentProc1CallAddress;
size_t mapAdjustmentProc2ReturnAddress;
size_t mapAdjustmentProc3ReturnAddress1;
size_t mapAdjustmentProc3ReturnAddress2;
size_t mapAdjustmentProc4ReturnAddress;
size_t mapAdjustmentProc5ReturnAddress;
size_t mapAdjustmentProc5SeparatorAddress;

// FIXME: convertWideTextToEscapedText のD言語版関数をescape_tool.dに定義し、ここで呼び出す
// 現状はダミーの関数定義のみ
void convertWideTextToEscapedText(wchar_t* wideText, char** escapedText) {
    writeln("Dummy convertWideTextToEscapedText called.");
    // ダミーとして適当な文字列を割り当てる
    *escapedText = cast(char*)malloc(2);
    (*escapedText)[0] = 'X';
    (*escapedText)[1] = '\0';
}

char* mapAdjustmentProc5InjectorSeparateBuffer;

DllError mapAdjustmentProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
         EU4Ver.v1_29_3_0,
         EU4Ver.v1_29_4_0: {
        // movsx ecx, byte ptr [rdi + rbx]
        BytePattern.tempInstance().findPattern("0F BE 0C 1F E8 ? ? ? ? 88 04 1F 41 FF");
        if (BytePattern.tempInstance().hasSize(1, "マップ文字の大文字化キャンセル")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx}
            // mapAdjustmentProc1CallAddress = Injector::GetBranchDestination(address + 0x04).as_int();
            mapAdjustmentProc1CallAddress = address + 0x05; // 仮のアドレス

            // cmp byte ptr [rdi + r14] , 0
            mapAdjustmentProc1ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc1, true);
            writeln("Dummy JMP for mapAdjustmentProc1Injector (v1_29_X) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc1Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0,
         EU4Ver.v1_30_4_0,
         EU4Ver.v1_30_3_0,
         EU4Ver.v1_30_2_0,
         EU4Ver.v1_30_1_0,
         EU4Ver.v1_31_1_0,
         EU4Ver.v1_31_2_0,
         EU4Ver.v1_31_3_0,
         EU4Ver.v1_31_4_0,
         EU4Ver.v1_31_5_0,
         EU4Ver.v1_31_6_0,
         EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
        // movsx ecx, byte ptr [rdi + rbx]
        BytePattern.tempInstance().findPattern("0F BE 0C 1F E8 ? ? ? ? 88 04 1F 41 FF");
        if (BytePattern.tempInstance().hasSize(2, "マップ文字の大文字化キャンセル")) {
            size_t address = BytePattern.tempInstance().getSecond().address;

            // call {sub_xxxxx}
            // mapAdjustmentProc1CallAddress = Injector::GetBranchDestination(address + 0x04).as_int();
            mapAdjustmentProc1CallAddress = address + 0x05; // 仮のアドレス

            // cmp byte ptr [rdi + r14] , 0
            mapAdjustmentProc1ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc1, true);
            writeln("Dummy JMP for mapAdjustmentProc1Injector (v1_30_X_plus) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionMapAdjustmentProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError mapAdjustmentProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
         EU4Ver.v1_29_3_0,
         EU4Ver.v1_29_4_0: {
        // lea     rax, [rbp+1F0h+var_1F0]
        BytePattern.tempInstance().findPattern("48 8D 45 00 49 83 C8 FF 90 49 FF C0");
        if (BytePattern.tempInstance().hasSize(2, "文字チェック修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // lea     rdx, [rbp+1F0h+var_1F0]
            mapAdjustmentProc2ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc2, true);
            writeln("Dummy JMP for mapAdjustmentProc2Injector (v1_29_X) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0,
         EU4Ver.v1_30_4_0,
         EU4Ver.v1_30_3_0,
         EU4Ver.v1_30_2_0,
         EU4Ver.v1_30_1_0,
         EU4Ver.v1_31_1_0,
         EU4Ver.v1_31_2_0,
         EU4Ver.v1_31_3_0,
         EU4Ver.v1_31_4_0,
         EU4Ver.v1_31_5_0,
         EU4Ver.v1_31_6_0: {
        // lea     rax, [rbp+200h+var_200]
        BytePattern.tempInstance().findPattern("48 8D 45 00 49 83 C8 FF 90 49 FF C0");
        if (BytePattern.tempInstance().hasSize(1, "文字チェック修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // lea     rdx, [rbp+200h+var_200]
            mapAdjustmentProc2ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc2V130, true);
            writeln("Dummy JMP for mapAdjustmentProc2Injector (v1_30_X_v131) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
        // lea     rax, [rbp+200h+var_200]
        BytePattern.tempInstance().findPattern("48 8D 45 00 49 83 C8 FF 90 49 FF C0");
        if (BytePattern.tempInstance().hasSize(1, "文字チェック修正") ||
            BytePattern.tempInstance().hasSize(2, "文字チェック修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // lea     rdx, [rbp+200h+var_200]
            mapAdjustmentProc2ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc2V130, true);
            writeln("Dummy JMP for mapAdjustmentProc2Injector (v1_32_X_plus) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc2Injector = true;
        }
        break;
    }
    default: {
        e.versionMapAdjustmentProc2Injector = true;
        break;
    }
    }

    return e;
}

DllError mapAdjustmentProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
         EU4Ver.v1_29_3_0,
         EU4Ver.v1_29_4_0: {
        // r9, 0FFFFFFFFFFFFFFFFh
        BytePattern.tempInstance().findPattern("49 83 C9 FF 45 33 C0 48 8D 95 C0 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "文字チェックの後のコピー処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call    sub_xxxxx
            mapAdjustmentProc3ReturnAddress1 = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc3, true);
            writeln("Dummy JMP for mapAdjustmentProc3Injector (v1_29_X) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }

        // mov     rcx, [r12+30h]
        BytePattern.tempInstance().findPattern("49 8B 4C 24 30 48 8B 01 C6 44 24 30 01");
        if (BytePattern.tempInstance().hasSize(2, "文字チェックの後のコピー処理の戻り先２")) {
            mapAdjustmentProc3ReturnAddress2 = BytePattern.tempInstance().getSecond().address;
            writeln("Dummy GetSecondAddress for mapAdjustmentProc3Injector (v1_29_X) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0,
         EU4Ver.v1_30_4_0,
         EU4Ver.v1_30_3_0,
         EU4Ver.v1_30_2_0,
         EU4Ver.v1_30_1_0,
         EU4Ver.v1_31_1_0,
         EU4Ver.v1_31_2_0,
         EU4Ver.v1_31_3_0,
         EU4Ver.v1_31_4_0,
         EU4Ver.v1_31_5_0,
         EU4Ver.v1_31_6_0,
         EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
        // r9, 0FFFFFFFFFFFFFFFFh
        BytePattern.tempInstance().findPattern("49 83 C9 FF 45 33 C0 48 8D 95 D0 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "文字チェックの後のコピー処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call    sub_xxxxx
            mapAdjustmentProc3ReturnAddress1 = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc3V130, true);
            writeln("Dummy JMP for mapAdjustmentProc3Injector (v1_30_X_plus) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }

        // mov     rcx, [r12+30h]
        BytePattern.tempInstance().findPattern("49 8B 4C 24 30 48 8B 01 C6 44 24 30 01");
        if (BytePattern.tempInstance().hasSize(2, "文字チェックの後のコピー処理の戻り先２")) {
            mapAdjustmentProc3ReturnAddress2 = BytePattern.tempInstance().getSecond().address;
            writeln("Dummy GetSecondAddress for mapAdjustmentProc3Injector (v1_30_X_plus) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }
        break;
    }
    default: {
        e.versionMapAdjustmentProc3Injector = true;
        break;
    }
    }

    return e;
}

DllError mapAdjustmentProc4Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
         EU4Ver.v1_29_3_0,
         EU4Ver.v1_29_4_0: {
        //  lea     rax, [rbp+1F0h+var_160]
        BytePattern.tempInstance().findPattern("48 8D 85 90 00 00 00 49 83 F8 10");
        if (BytePattern.tempInstance().hasSize(1, "文字取得処理修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // mov     rdx, [r15+rax*8]
            mapAdjustmentProc4ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc4, true);
            writeln("Dummy JMP for mapAdjustmentProc4Injector (v1_29_X) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc4Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0,
         EU4Ver.v1_30_4_0,
         EU4Ver.v1_30_3_0,
         EU4Ver.v1_30_2_0,
         EU4Ver.v1_30_1_0,
         EU4Ver.v1_31_1_0,
         EU4Ver.v1_31_2_0,
         EU4Ver.v1_31_3_0,
         EU4Ver.v1_31_4_0,
         EU4Ver.v1_31_5_0,
         EU4Ver.v1_31_6_0,
         EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
        //  lea     rax, [rbp+200h+var_160]
        BytePattern.tempInstance().findPattern("48 8D 85 A0 00 00 00 49 83 F8 10");
        if (BytePattern.tempInstance().hasSize(1, "文字取得処理修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // mov     rdx, [r15+rax*8]
            mapAdjustmentProc4ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc4V130, true);
            writeln("Dummy JMP for mapAdjustmentProc4Injector (v1_30_X_plus) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc4Injector = true;
        }
        break;
    }
    default: {
        e.versionMapAdjustmentProc4Injector = true;
        break;
    }
    }

    return e;
}

DllError mapAdjustmentProc5Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_2_0,
         EU4Ver.v1_29_3_0,
         EU4Ver.v1_29_4_0,
         EU4Ver.v1_30_1_0,
         EU4Ver.v1_30_2_0,
         EU4Ver.v1_30_3_0,
         EU4Ver.v1_30_4_0,
         EU4Ver.v1_30_5_0,
         EU4Ver.v1_31_1_0,
         EU4Ver.v1_31_2_0,
         EU4Ver.v1_31_3_0,
         EU4Ver.v1_31_4_0,
         EU4Ver.v1_31_5_0,
         EU4Ver.v1_31_6_0: {
        // lea r8, asc_xxxxx
        BytePattern.tempInstance().findPattern("4C 8D 05 ? ? ? ? 48 8D 55 78 48 8D 8D 40 01");
        if (BytePattern.tempInstance().hasSize(1, "区切り記号の変更（ISSUE-164）")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // D言語のwcharは2バイトなので、wchar_tをchar16_tに置き換える
            // char16_t[2] x = [cast(char16_t)options.separateCharacterCodePoint, 0];
            // FIXME: convertWideTextToEscapedText は現在ダミー実装
            // char* escapedChar = null;
            // convertWideTextToEscapedText(cast(wchar_t*)x.ptr, &escapedChar); 
            // size_t len = strlen(escapedChar);
            // size_t lenWithNull = len + 1;
            
            // D言語の動的配列に置き換え
            // mapAdjustmentProc5InjectorSeparateBuffer = new char[lenWithNull](); // D言語の配列で初期化
            // mapAdjustmentProc5InjectorSeparateBuffer = cast(char*) malloc(lenWithNull);
            // if (mapAdjustmentProc5InjectorSeparateBuffer is null) {
            //     // エラー処理
            //     e.unmatchdMapAdjustmentProc5Injector = true; // 仮のエラーフラグ
            //     return e;
            // }
            // memcpy(mapAdjustmentProc5InjectorSeparateBuffer, escapedChar, len);
            // mapAdjustmentProc5InjectorSeparateBuffer[len] = '\0'; // Null終端

            // mapAdjustmentProc5SeparatorAddress = cast(size_t)mapAdjustmentProc5InjectorSeparateBuffer;

            // call sub_xxxxx
            mapAdjustmentProc5ReturnAddress = address + 0x12;

            // Injector::MakeJMP(address, cast(size_t)mapAdjustmentProc5, true);
            writeln("Dummy JMP for mapAdjustmentProc5Injector called.");
        }
        else {
            e.unmatchdMapAdjustmentProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
        // localization/tmm_l_english.ymlのENCLAVE_NAME_FORMATで対応された
        break;
    }

    default: {
        e.versionMapAdjustmentProc5Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;
    // FIXME: RunOptionsにseparateCharacterCodePointがないため仮の値を設定
    options.separateCharacterCodePoint = 0x2D; // ダミー値 '-'

    result = result | mapAdjustmentProc1Injector(options);
    result = result | mapAdjustmentProc2Injector(options);
    result = result | mapAdjustmentProc3Injector(options);
    result = result | mapAdjustmentProc4Injector(options);
    result = result | mapAdjustmentProc5Injector(options);

    return result;
}
