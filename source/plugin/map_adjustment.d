module plugin.map_adjustment;

import std.stdio;
import std.string; // toHexString
import core.stdc.string; // memcpy, strlen
import core.stdc.stdlib; // malloc, free
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import plugin.localization.escape_codec : encodeCodePoint; // 上流 escape_tool.cpp の移植（convertWideTextToEscapedText 本体）

extern(C) {
    void* mapAdjustmentProc1() { return null; }
    void* mapAdjustmentProc2() { return null; }
    void* mapAdjustmentProc2V130() { return null; }
    void* mapAdjustmentProc3() { return null; }
    void* mapAdjustmentProc3V130() { return null; }
    void* mapAdjustmentProc4() { return null; }
    void* mapAdjustmentProc4V130() { return null; }
    void* mapAdjustmentProc5() { return null; }
}

size_t mapAdjustmentProc1ReturnAddress;
size_t mapAdjustmentProc1CallAddress;
size_t mapAdjustmentProc2ReturnAddress;
size_t mapAdjustmentProc3ReturnAddress1;
size_t mapAdjustmentProc3ReturnAddress2;
size_t mapAdjustmentProc4ReturnAddress;
size_t mapAdjustmentProc5ReturnAddress;
size_t mapAdjustmentProc5SeparatorAddress;

// 上流 escape_tool.cpp の convertWideTextToEscapedText の移植。
// 変換規則そのものは plugin.localization.escape_codec の
// encodeCodePoint（上流 escape_tool.cpp の移植）を使う。
// 入力は上流と同じく16ビット単位の並びとして読む（呼び出し側は
// char16_t のデータから組み立てる）。出力は malloc した
// NUL 終端バッファで、呼び出し側が free する。
void convertWideTextToEscapedText(wchar_t* wideText, char** escapedText) {
    if (wideText is null) {
        // 上流は from == NULL のとき *to に触れない。
        return;
    }

    auto units = cast(const(wchar)*) wideText;
    ubyte[] result;
    for (size_t i = 0; units[i] != 0; i++) {
        ubyte[] piece;
        if (!encodeCodePoint(cast(dchar) units[i], piece)) {
            // 16ビット単位では起こらない。上流にも表現方法がない
            // コードポイントなので、何も出さない。
            continue;
        }
        result ~= piece;
    }

    auto buffer = cast(char*) malloc(result.length + 1);
    if (buffer is null) {
        *escapedText = null;
        return;
    }
    if (result.length > 0) {
        memcpy(buffer, result.ptr, result.length);
    }
    buffer[result.length] = '\0';
    *escapedText = buffer;
}

char* mapAdjustmentProc5InjectorSeparateBuffer;

// ---------------------------------------------------------------------
// Linux v1.37.5: CString::ToUpper / CString::ToLower のループ。
//
// AddNameArea はマップ名のコピーを ToUpper に通してから描く。
// エスケープ列のワードのバイトには小文字の ASCII (0x61-0x7A) が
// 含まれ得るため、そのまま toupper を呼ぶとワードが壊れる
// （例: U+6771 のワード 0x6771 は 0x71='q' と 0x67='g' を含む）。
// 上流 proc1 と同じく、変換ループの中でエスケープバイト
// (0x10-0x13) を見たら変換せずに3バイト分進める。
//
// Linux ではこのループは CString::ToUpper / ToLower の中にある。
// 両関数は同じ命令列で、ループ先頭15バイトをパッチする。
// エスケープ時の前進処理はパッチ範囲の中にあるため、フック側で
// 複製する。定数は plugin.main_text と同じ値。
// ---------------------------------------------------------------------

enum ESCAPE_SEQ_1 = 0x10;
enum ESCAPE_SEQ_4 = 0x13;

// __gshared is required for globals referenced from naked asm
// (a TLS global makes the compiler emit a register-destroying
// __tls_get_addr prologue; see plugin.main_text).
__gshared size_t mapAdjProc1V137ToUpperCallAddress;
__gshared size_t mapAdjProc1V137ToUpperReturnAddress;
__gshared size_t mapAdjProc1V137ToUpperLoopAddress;
__gshared size_t mapAdjProc1V137ToUpperExitAddress;
__gshared size_t mapAdjProc1V137ToLowerCallAddress;
__gshared size_t mapAdjProc1V137ToLowerReturnAddress;
__gshared size_t mapAdjProc1V137ToLowerLoopAddress;
__gshared size_t mapAdjProc1V137ToLowerExitAddress;

// On entry AL = current byte, RBX = data + index, EBP = index + 1,
// R15 = data base, R14 = string length. The normal path replays the
// patched instructions (movsx / call toupper / store / mov / cmp)
// and returns at the jbe after them. The escape path replicates the
// vanilla advance code (which is inside the patched region) and
// either exits to the function epilogue or jumps back to the
// patched loop head.
void mapAdjustmentProc1V137ToUpper_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            cmp       AL, ESCAPE_SEQ_1;
            jb        JMP_N;
            cmp       AL, ESCAPE_SEQ_4;
            ja        JMP_N;
            add       EBP, 2;
            mov       EAX, EBP;
            cmp       RAX, R14;
            ja        JMP_C;
            lea       R11, [mapAdjProc1V137ToUpperExitAddress];
            jmp       qword ptr [R11];
        JMP_C:
            lea       RBX, [R15 + RAX];
            mov       AL, byte ptr [R15 + RAX];
            inc       EBP;
            test      AL, AL;
            jnz       JMP_L;
            lea       R11, [mapAdjProc1V137ToUpperExitAddress];
            jmp       qword ptr [R11];
        JMP_L:
            lea       R11, [mapAdjProc1V137ToUpperLoopAddress];
            jmp       qword ptr [R11];
        JMP_N:
            movsx     EDI, AL;
            lea       R11, [mapAdjProc1V137ToUpperCallAddress];
            mov       R11, qword ptr [R11];
            call      R11;
            mov       byte ptr [RBX], AL;
            mov       EAX, EBP;
            cmp       RAX, R14;
            lea       R11, [mapAdjProc1V137ToUpperReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

// Same shape as the ToUpper hook, for CString::ToLower (calls
// tolower instead; the game itself only uppercases map names, but
// upstream fixes both loops and the same corruption applies).
void mapAdjustmentProc1V137ToLower_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            cmp       AL, ESCAPE_SEQ_1;
            jb        JMP_N;
            cmp       AL, ESCAPE_SEQ_4;
            ja        JMP_N;
            add       EBP, 2;
            mov       EAX, EBP;
            cmp       RAX, R14;
            ja        JMP_C;
            lea       R11, [mapAdjProc1V137ToLowerExitAddress];
            jmp       qword ptr [R11];
        JMP_C:
            lea       RBX, [R15 + RAX];
            mov       AL, byte ptr [R15 + RAX];
            inc       EBP;
            test      AL, AL;
            jnz       JMP_L;
            lea       R11, [mapAdjProc1V137ToLowerExitAddress];
            jmp       qword ptr [R11];
        JMP_L:
            lea       R11, [mapAdjProc1V137ToLowerLoopAddress];
            jmp       qword ptr [R11];
        JMP_N:
            movsx     EDI, AL;
            lea       R11, [mapAdjProc1V137ToLowerCallAddress];
            mov       R11, qword ptr [R11];
            call      R11;
            mov       byte ptr [RBX], AL;
            mov       EAX, EBP;
            cmp       RAX, R14;
            lea       R11, [mapAdjProc1V137ToLowerReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

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
            mapAdjustmentProc1CallAddress = address + 0x04 + get_branch_destination_offset(cast(void*)(address + 0x04), 4); // 仮のアドレス

            // cmp byte ptr [rdi + r14] , 0
            mapAdjustmentProc1ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc1));
            writeln("JMP for mapAdjustmentProc1Injector (v1_29_X) created.");
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
            mapAdjustmentProc1CallAddress = address + 0x04 + get_branch_destination_offset(cast(void*)(address + 0x04), 4); // 仮のアドレス

            // cmp byte ptr [rdi + r14] , 0
            mapAdjustmentProc1ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc1));
            writeln("JMP for mapAdjustmentProc1Injector (v1_30_X_plus) created.");
        }
        else {
            e.unmatchdMapAdjustmentProc1Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: CString::ToUpper / ToLower の変換ループ
        // （フックのコメント参照）。命令列は両関数で共通で、
        // call の相対オフセットだけが違うため別パターンにする。
        // パッチは15バイトで、戻り先は直後の jbe。
        BytePattern.tempInstance().findPattern("0F BE F8 E8 18 64 7F FE 88 03 89 E8 49 39 C6 76 0E");
        if (BytePattern.tempInstance().hasSize(1, "マップ文字の大文字化キャンセル (v1.37.5 ToUpper)")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            mapAdjProc1V137ToUpperCallAddress = address + 8 + *cast(int*)(address + 4);
            mapAdjProc1V137ToUpperReturnAddress = address + 15;
            mapAdjProc1V137ToUpperLoopAddress = address;
            mapAdjProc1V137ToUpperExitAddress = address + 0x1F;

            PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapAdjustmentProc1V137ToUpper_hook, 15);
            writeln("JMP for mapAdjustmentProc1Injector (v1.37.5 ToUpper) created.");
        }
        else {
            e.unmatchdMapAdjustmentProc1Injector = true;
        }

        BytePattern.tempInstance().findPattern("0F BE F8 E8 E4 88 7F FE 88 03 89 E8 49 39 C6 76 0E");
        if (BytePattern.tempInstance().hasSize(1, "マップ文字の大文字化キャンセル (v1.37.5 ToLower)")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            mapAdjProc1V137ToLowerCallAddress = address + 8 + *cast(int*)(address + 4);
            mapAdjProc1V137ToLowerReturnAddress = address + 15;
            mapAdjProc1V137ToLowerLoopAddress = address;
            mapAdjProc1V137ToLowerExitAddress = address + 0x1F;

            PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapAdjustmentProc1V137ToLower_hook, 15);
            writeln("JMP for mapAdjustmentProc1Injector (v1.37.5 ToLower) created.");
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc2));
            writeln("JMP for mapAdjustmentProc2Injector (v1_29_X) created.");
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc2V130));
            writeln("JMP for mapAdjustmentProc2Injector (v1_30_X_v131) created.");
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc2V130));
            writeln("JMP for mapAdjustmentProc2Injector (v1_32_X_plus) created.");
        }
        else {
            e.unmatchdMapAdjustmentProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: 1文字を取り出す処理は AddNameArea の
        // 間隔挿入ループに内蔵されており、そちらは MapJustify
        // (plugin.map_justify proc1 v1.37.5) が担当する。
        // ここでパッチする箇所はない。
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc3));
            writeln("JMP for mapAdjustmentProc3Injector (v1_29_X) created.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }

        // mov     rcx, [r12+30h]
        BytePattern.tempInstance().findPattern("49 8B 4C 24 30 48 8B 01 C6 44 24 30 01");
        if (BytePattern.tempInstance().hasSize(2, "文字チェックの後のコピー処理の戻り先２")) {
            mapAdjustmentProc3ReturnAddress2 = BytePattern.tempInstance().getSecond().address;
            writeln("GetSecondAddress for mapAdjustmentProc3Injector (v1_29_X) called.");
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc3V130));
            writeln("JMP for mapAdjustmentProc3Injector (v1_30_X_plus) created.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }

        // mov     rcx, [r12+30h]
        BytePattern.tempInstance().findPattern("49 8B 4C 24 30 48 8B 01 C6 44 24 30 01");
        if (BytePattern.tempInstance().hasSize(2, "文字チェックの後のコピー処理の戻り先２")) {
            mapAdjustmentProc3ReturnAddress2 = BytePattern.tempInstance().getSecond().address;
            writeln("GetSecondAddress for mapAdjustmentProc3Injector (v1_30_X_plus) called.");
        }
        else {
            e.unmatchdMapAdjustmentProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: proc2 と同じく、コピー処理は AddNameArea
        // の間隔挿入ループ側 (MapJustify) で扱う。
        // ここでパッチする箇所はない。
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc4));
            writeln("JMP for mapAdjustmentProc4Injector (v1_29_X) created.");
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

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc4V130));
            writeln("JMP for mapAdjustmentProc4Injector (v1_30_X_plus) created.");
        }
        else {
            e.unmatchdMapAdjustmentProc4Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: 文字コードの抽出は MapView の取得フック
        // (plugin.map_view v1.37.5) と MapJustify の間隔挿入
        // フックが担う。ここでパッチする箇所はない。
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

            mapAdjustmentProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapAdjustmentProc5));
            writeln("JMP for mapAdjustmentProc5Injector created.");
        }
        else {
            e.unmatchdMapAdjustmentProc5Injector = true;
        }
        break;
    }
    case EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0,
         EU4Ver.v1_37_5: {
        // localization/tmm_l_english.ymlのENCLAVE_NAME_FORMATで対応された
        // (v1.37.5 も上流 v1.37 と同じくローカライズ側で対応済み)
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
