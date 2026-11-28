module plugin.map_justify;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

extern(C) {
    void* mapJustifyProc1() { return null; }
    void* mapJustifyProc2() { return null; }
    void* mapJustifyProc4() { return null; }
}

size_t mapJustifyProc1ReturnAddress1;
size_t mapJustifyProc1ReturnAddress2;
size_t mapJustifyProc2ReturnAddress;
size_t mapJustifyProc4ReturnAddress;

// ---------------------------------------------------------------------
// Linux v1.37.5: AddNameArea の文字間隔挿入ループ。
//
// AddNameArea は名前の各バイトの後に空白を挟んだ表示形を作る
// （名前が短いときに文字を広げて配置するための形）。バイト単位で
// 挟むとエスケープ列（3バイト）が壊れるため、上流 MapJustify の
// 文字取得フックに相当するものとして、取得箇所でエスケープ列を
// 1文字として扱う。対象は2か所:
//   site1: ループ内の取得。エスケープ時は3バイトを一時バッファへ
//          書き、インデックスを2つ余分に進める。
//   site2: ループ後に最後の1文字を取る取得。最後の文字がエスケープ
//          列のときはループ側で追加済みなので何も追加しない。
// あわせて、エスケープでインデックスが終端を飛び越える場合に
// ループを抜けられるよう、ループ末尾の継続条件を jne から ja に
// 変える（通常の文字列では到達する値が同じで、動作は変わらない）。
// 定数は plugin.main_text と同じ値。
// ---------------------------------------------------------------------

enum ESCAPE_SEQ_1 = 0x10;
enum ESCAPE_SEQ_4 = 0x13;

// __gshared is required for globals referenced from naked asm
// (a TLS global makes the compiler emit a register-destroying
// __tls_get_addr prologue; see plugin.main_text).
__gshared size_t mapJustifyProc1V137Site1ReturnAddress;
__gshared size_t mapJustifyProc1V137Site2ReturnAddress;

// Site 1: on entry R13 = string data, R12 = byte index,
// R14 = the spaced CString being built, and the 4-byte temp buffer
// is at [RBP-0x88]. The hook writes the current character (1 byte,
// or the 3 bytes of an escape sequence) plus a NUL into the temp
// buffer and replays the RDI setup for the operator+= call that
// follows at the return point.
void mapJustifyProc1V137Site1_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            movzx     EAX, byte ptr [R13 + R12];
            cmp       AL, ESCAPE_SEQ_1;
            jb        JMP_N;
            cmp       AL, ESCAPE_SEQ_4;
            ja        JMP_N;
            mov       byte ptr [RBP - 0x88], AL;
            movzx     EAX, byte ptr [R13 + R12 + 1];
            mov       byte ptr [RBP - 0x87], AL;
            movzx     EAX, byte ptr [R13 + R12 + 2];
            mov       byte ptr [RBP - 0x86], AL;
            mov       byte ptr [RBP - 0x85], 0;
            add       R12, 2;
            jmp       JMP_E;
        JMP_N:
            mov       byte ptr [RBP - 0x88], AL;
            mov       byte ptr [RBP - 0x87], 0;
        JMP_E:
            mov       RDI, R14;
            lea       R11, [mapJustifyProc1V137Site1ReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

// Site 2: on entry RAX = string size, R13 = string data,
// R14 = the spaced CString. The vanilla code appends the byte at
// [size-1]. The hook walks the string with escape awareness: if
// the last character is a single byte it is appended as before;
// if it is an escape sequence, the site-1 loop already appended
// it, so an empty string is appended instead.
void mapJustifyProc1V137Site2_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            xor       ECX, ECX;
            xor       EDX, EDX;
        JMP_W:
            cmp       RCX, RAX;
            jae       JMP_D;
            mov       RDX, RCX;
            movzx     R8D, byte ptr [R13 + RCX];
            cmp       R8D, ESCAPE_SEQ_1;
            jb        JMP_S;
            cmp       R8D, ESCAPE_SEQ_4;
            ja        JMP_S;
            add       RCX, 3;
            jmp       JMP_W;
        JMP_S:
            inc       RCX;
            jmp       JMP_W;
        JMP_D:
            lea       R8, [RAX - 1];
            cmp       RDX, R8;
            jne       JMP_X;
            movzx     EAX, byte ptr [R13 + RDX];
            mov       byte ptr [RBP - 0x88], AL;
            mov       byte ptr [RBP - 0x87], 0;
            jmp       JMP_E;
        JMP_X:
            mov       byte ptr [RBP - 0x88], 0;
            mov       byte ptr [RBP - 0x87], 0;
        JMP_E:
            mov       RDI, R14;
            lea       R11, [mapJustifyProc1V137Site2ReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

DllError mapJustifyProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
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
         EU4Ver.v1_31_6_0,
         EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
            // movsd   xmm3, [rbp+1D0h+var_168]
            BytePattern.tempInstance().findPattern("F2 0F 10 5D 68 FF C2 F2 0F 10 65 20");
            if (BytePattern.tempInstance().hasSize(1, "文字取得処理リターン先２")) {
                mapJustifyProc1ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
            }
            else {
                e.unmatchdMapJustifyProc1Injector = true;
            }

            // movzx   esi, byte ptr [rax+r13]
            BytePattern.tempInstance().findPattern("42 0F B6 34 28 F3 44 0F 10 89 48 08 00 00");
            if (BytePattern.tempInstance().hasSize(1, "文字取得処理")) {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cmp     word ptr [rdi+6], 0
                mapJustifyProc1ReturnAddress1 = address + 0x1B;

                PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapJustifyProc1));
                writeln("JMP for mapJustifyProc1Injector created.");
            }
            else {
                e.unmatchdMapJustifyProc1Injector = true;
            }
            break;
    }
    case EU4Ver.v1_37_5: {
            // Linux v1.37.5: AddNameArea の文字間隔挿入ループ
            // （フックのコメント参照）。パッチは各14バイトで、
            // 戻り先は operator+= の引数組み立て箇所。
            BytePattern.tempInstance().findPattern("43 8A 44 25 00 88 85 78 FF FF FF 4C 89 F7 48 8D B5 78 FF FF FF");
            if (BytePattern.tempInstance().hasSize(1, "文字取得処理 (v1.37.5 間隔挿入ループ)")) {
                size_t address = BytePattern.tempInstance().getFirst().address;

                mapJustifyProc1V137Site1ReturnAddress = address + 14;

                PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapJustifyProc1V137Site1_hook, 14);
                writeln("JMP for mapJustifyProc1Injector (v1.37.5 spacing site 1) created.");
            }
            else {
                e.unmatchdMapJustifyProc1Injector = true;
            }

            BytePattern.tempInstance().findPattern("42 8A 44 28 FF 88 85 78 FF FF FF 4C 89 F7 48 8D B5 78 FF FF FF");
            if (BytePattern.tempInstance().hasSize(1, "文字取得処理 (v1.37.5 間隔挿入ループ末尾)")) {
                size_t address = BytePattern.tempInstance().getFirst().address;

                mapJustifyProc1V137Site2ReturnAddress = address + 14;

                PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapJustifyProc1V137Site2_hook, 14);
                writeln("JMP for mapJustifyProc1Injector (v1.37.5 spacing site 2) created.");
            }
            else {
                e.unmatchdMapJustifyProc1Injector = true;
            }

            // ループ末尾の継続条件 jne -> ja（フックのコメント参照）
            BytePattern.tempInstance().findPattern("4C 8B AD B0 FE FF FF 4D 39 E7 75 CC");
            if (BytePattern.tempInstance().hasSize(1, "間隔挿入ループの継続条件 (v1.37.5)")) {
                size_t address = BytePattern.tempInstance().getFirst().address;

                ubyte[2] exitPatch = [0x77, 0xCC];
                PatchManager.instance().addPatch(cast(void*)(address + 10), exitPatch[]);
                writeln("Byte patch for mapJustifyProc1Injector (v1.37.5 spacing loop exit) created.");
            }
            else {
                e.unmatchdMapJustifyProc1Injector = true;
            }
            break;
    }
    default: {
        e.versionMapJustifyProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError mapJustifyProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
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
         EU4Ver.v1_31_6_0,
         EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
            // lea     eax, [r10-1]
            BytePattern.tempInstance().findPattern("41 8D 42 FF 66 0F 6E F2 66 0F 6E C0");
            if (BytePattern.tempInstance().hasSize(1, "一文字表示の調整")) {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cvtdq2ps xmm6, xmm6
                mapJustifyProc2ReturnAddress = address + 0xF;

                PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapJustifyProc2));
                writeln("JMP for mapJustifyProc2Injector created.");
            }
            else {
                e.unmatchdMapJustifyProc2Injector = true;
            }
            break;
    }
    case EU4Ver.v1_37_5: {
            // Linux v1.37.5: 1文字表示の調整に相当する処理は
            // CurveText の配分計算に含まれ、専用の取得箇所はない。
            // ここでパッチする箇所はない。
            break;
    }
    default: {
        e.versionMapJustifyProc2Injector = true;
        break;
    }
    }

    return e;
}

DllError mapJustifyProc4Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0,
         EU4Ver.v1_29_2_0,
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
         EU4Ver.v1_31_6_0,
         EU4Ver.v1_32_0_1,
         EU4Ver.v1_33_0_0,
         EU4Ver.v1_33_3_0: {
            // movsd   xmm3, [rbp+1D0h+var_168]
            BytePattern.tempInstance().findPattern("F2 0F 10 5D 68 FF C2 F2 0F 10 65 20");
            if (BytePattern.tempInstance().hasSize(1, "カウント処理")) {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cmp     r13, rax
                mapJustifyProc4ReturnAddress = address + 0x1E;

                PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapJustifyProc4));
                writeln("JMP for mapJustifyProc4Injector created.");
            }
            else {
                e.unmatchdMapJustifyProc4Injector = true;
            }
            break;
    }
    case EU4Ver.v1_37_5: {
            // Linux v1.37.5: カウント処理は MapView のカウント
            // フック (plugin.map_view proc2 v1.37.5) が担う。
            // ここでパッチする箇所はない。
            break;
    }
    default: {
        e.versionMapJustifyProc4Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | mapJustifyProc1Injector(options);
    result = result | mapJustifyProc2Injector(options);
    result = result | mapJustifyProc4Injector(options);

    return result;
}
