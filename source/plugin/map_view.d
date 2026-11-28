module plugin.map_view;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import plugin.glyph_table : wideGlyphLookup; // Linux v1.37.5: 0x100以上のグリフ引き

extern(C) {
    void* mapViewProc1() { return null; }
    void* mapViewProc2() { return null; }
    void* mapViewProc2V130() { return null; }
    void* mapViewProc3() { return null; }
}

size_t mapViewProc1ReturnAddress;
size_t mapViewProc2ReturnAddress;
size_t mapViewProc3ReturnAddress;
size_t mapViewProc3CallAddress;

// ---------------------------------------------------------------------
// Linux v1.37.5 (item: map name rendering)
//
// On Linux the upstream MapView host function (one function holding
// both fetch loops) is split by the compiler into two functions:
//   - CGenerateNamesWork::AddNameArea / CCountryNameCollection::
//     AddNudgedNames: a counting loop that fetches one byte per
//     character to size the vertex array (upstream loop 1 role).
//   - CurveText (file-local): the render loop that fetches one byte
//     per character and emits the curved vertices (upstream loop 2
//     role).
// Both fetch the byte through CString::operator[] and then index the
// font's embedded glyph table, so an escaped Japanese name (3 bytes
// per character) is read as Latin-1 bytes and only the trailing 0x30
// byte ('0') of each sequence has a glyph. The hooks below decode
// the escape sequence at the fetch point, advance the loop index by
// 2 extra bytes, replicate the original glyph fetch (embedded table
// below 0x100, wideGlyphLookup at and above 0x100), and apply the
// upstream hyphen fallback (glyph missing and code point >= 0xFF
// falls back to '-'). Constants mirror plugin.main_text.
// ---------------------------------------------------------------------

enum ESCAPE_SEQ_1 = 0x10;
enum ESCAPE_SEQ_2 = 0x11;
enum ESCAPE_SEQ_3 = 0x12;
enum ESCAPE_SEQ_4 = 0x13;
enum SHIFT_2 = 0x0E;
enum SHIFT_3 = 0x900;
enum SHIFT_4 = 0x8F2;
enum NO_FONT = 0x98F;
enum NOT_DEF = 0x2026;

// __gshared is required: a plain (TLS) global makes the compiler
// emit a __tls_get_addr prologue in front of the naked asm, which
// destroys the game's registers before the hook body runs (the same
// reason plugin.main_text marks its v1.37.5 globals __gshared).
__gshared size_t mapViewGlyphLookupFuncAddress;
__gshared size_t mapViewProc1V137ReturnAddress;
__gshared size_t mapViewProc2V137AddNameAreaReturnAddress;
__gshared size_t mapViewProc2V137AddNudgedReturnAddress;

// CurveText fetch site. On entry RAX = CString::operator[] result
// (pointer to the current byte), R12 = CBitmapCharacterSet base
// (font base + 0x100, the embedded glyph table), R14D = byte index.
// The glyph must end up in R13, R15 must be reloaded from
// [RBP-0x108], and the flags of test R13,R13 must be live at the
// return point (the game continues with je on a null glyph).
// The site runs with RSP % 16 == 0 (6 pushes + sub 0x198 from an
// 8-misaligned entry), so the lookup call pushes exactly two
// registers, the same shape as plugin.main_text site A.
void mapViewProc1V137CurveText_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            mov       R11, RAX;
            movzx     EAX, byte ptr [R11];
            cmp       EAX, ESCAPE_SEQ_1;
            jz        JMP_A;
            cmp       EAX, ESCAPE_SEQ_2;
            jz        JMP_B;
            cmp       EAX, ESCAPE_SEQ_3;
            jz        JMP_C;
            cmp       EAX, ESCAPE_SEQ_4;
            jz        JMP_D;
            jmp       JMP_E;
        JMP_A:
            movzx     EAX, word ptr [R11 + 1];
            jmp       JMP_F;
        JMP_B:
            movzx     EAX, word ptr [R11 + 1];
            sub       EAX, SHIFT_2;
            jmp       JMP_F;
        JMP_C:
            movzx     EAX, word ptr [R11 + 1];
            add       EAX, SHIFT_3;
            jmp       JMP_F;
        JMP_D:
            movzx     EAX, word ptr [R11 + 1];
            add       EAX, SHIFT_4;
        JMP_F:
            movzx     EAX, AX;
            add       R14D, 2;
            cmp       EAX, NO_FONT;
            ja        JMP_E;
            mov       EAX, NOT_DEF;
        JMP_E:
            cmp       EAX, 0x100;
            jae       JMP_G;
            mov       R13, qword ptr [R12 + RAX*8];
            jmp       JMP_H;
        JMP_G:
            push      RAX;
            push      RCX;
            mov       RCX, R12;
            sub       RCX, 0x100;
            mov       RDI, RCX;
            mov       ESI, EAX;
            lea       R11, [mapViewGlyphLookupFuncAddress];
            mov       R11, qword ptr [R11];
            call      R11;
            mov       R13, RAX;
            pop       RCX;
            pop       RAX;
        JMP_H:
            test      R13, R13;
            jnz       JMP_I;
            cmp       EAX, 0xFF;
            jb        JMP_I;
            mov       R13, qword ptr [R12 + 0x2D*8];
        JMP_I:
            test      R13, R13;
            mov       R15, qword ptr [RBP - 0x108];
            lea       R11, [mapViewProc1V137ReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

// Counting-loop fetch site shared shape (AddNameArea and
// AddNudgedNames): on entry RAX = CString::operator[] result,
// R12 = CBitmapFont base (embedded table at +0x100), EBX = byte
// index. The glyph must end up in RAX with the flags of
// test RAX,RAX live at the return point. Both functions run with
// RSP % 16 == 0 at the site (6 pushes + a sub whose low nibble is
// 8), so the lookup call pushes exactly two registers.
void mapViewProc2V137AddNameAreaCount_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            mov       R11, RAX;
            movzx     EAX, byte ptr [R11];
            cmp       EAX, ESCAPE_SEQ_1;
            jz        JMP_A;
            cmp       EAX, ESCAPE_SEQ_2;
            jz        JMP_B;
            cmp       EAX, ESCAPE_SEQ_3;
            jz        JMP_C;
            cmp       EAX, ESCAPE_SEQ_4;
            jz        JMP_D;
            jmp       JMP_E;
        JMP_A:
            movzx     EAX, word ptr [R11 + 1];
            jmp       JMP_F;
        JMP_B:
            movzx     EAX, word ptr [R11 + 1];
            sub       EAX, SHIFT_2;
            jmp       JMP_F;
        JMP_C:
            movzx     EAX, word ptr [R11 + 1];
            add       EAX, SHIFT_3;
            jmp       JMP_F;
        JMP_D:
            movzx     EAX, word ptr [R11 + 1];
            add       EAX, SHIFT_4;
        JMP_F:
            movzx     EAX, AX;
            add       EBX, 2;
            cmp       EAX, NO_FONT;
            ja        JMP_E;
            mov       EAX, NOT_DEF;
        JMP_E:
            cmp       EAX, 0x100;
            jae       JMP_G;
            mov       EDX, EAX;
            mov       RAX, qword ptr [R12 + RAX*8 + 0x100];
            jmp       JMP_H;
        JMP_G:
            push      RAX;
            push      RCX;
            mov       RDI, R12;
            mov       ESI, EAX;
            lea       R11, [mapViewGlyphLookupFuncAddress];
            mov       R11, qword ptr [R11];
            call      R11;
            mov       EDX, dword ptr [RSP + 8];
            pop       RCX;
            pop       R11;
        JMP_H:
            test      RAX, RAX;
            jnz       JMP_I;
            cmp       EDX, 0xFF;
            jb        JMP_I;
            mov       RAX, qword ptr [R12 + 0x2D*8 + 0x100];
        JMP_I:
            test      RAX, RAX;
            lea       R11, [mapViewProc2V137AddNameAreaReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

// Same shape as the AddNameArea counting hook, for the counting
// loop in CCountryNameCollection::AddNudgedNames.
void mapViewProc2V137AddNudgedCount_hook()
{
    version (X86_64)
    {
        asm
        {
            naked;
            mov       R11, RAX;
            movzx     EAX, byte ptr [R11];
            cmp       EAX, ESCAPE_SEQ_1;
            jz        JMP_A;
            cmp       EAX, ESCAPE_SEQ_2;
            jz        JMP_B;
            cmp       EAX, ESCAPE_SEQ_3;
            jz        JMP_C;
            cmp       EAX, ESCAPE_SEQ_4;
            jz        JMP_D;
            jmp       JMP_E;
        JMP_A:
            movzx     EAX, word ptr [R11 + 1];
            jmp       JMP_F;
        JMP_B:
            movzx     EAX, word ptr [R11 + 1];
            sub       EAX, SHIFT_2;
            jmp       JMP_F;
        JMP_C:
            movzx     EAX, word ptr [R11 + 1];
            add       EAX, SHIFT_3;
            jmp       JMP_F;
        JMP_D:
            movzx     EAX, word ptr [R11 + 1];
            add       EAX, SHIFT_4;
        JMP_F:
            movzx     EAX, AX;
            add       EBX, 2;
            cmp       EAX, NO_FONT;
            ja        JMP_E;
            mov       EAX, NOT_DEF;
        JMP_E:
            cmp       EAX, 0x100;
            jae       JMP_G;
            mov       EDX, EAX;
            mov       RAX, qword ptr [R12 + RAX*8 + 0x100];
            jmp       JMP_H;
        JMP_G:
            push      RAX;
            push      RCX;
            mov       RDI, R12;
            mov       ESI, EAX;
            lea       R11, [mapViewGlyphLookupFuncAddress];
            mov       R11, qword ptr [R11];
            call      R11;
            mov       EDX, dword ptr [RSP + 8];
            pop       RCX;
            pop       R11;
        JMP_H:
            test      RAX, RAX;
            jnz       JMP_I;
            cmp       EDX, 0xFF;
            jb        JMP_I;
            mov       RAX, qword ptr [R12 + 0x2D*8 + 0x100];
        JMP_I:
            test      RAX, RAX;
            lea       R11, [mapViewProc2V137AddNudgedReturnAddress];
            jmp       qword ptr [R11];
        }
    }
}

DllError mapViewProc1Injector(RunOptions options) {
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
        // movzx   eax, byte ptr [rax+r8]
        BytePattern.tempInstance().findPattern("42 0F B6 04 00 4C 8B 1C C7 4C 89 5D 38");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ２の文字取得処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // test    r11, r11
            mapViewProc1ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapViewProc1));
            writeln("JMP for mapViewProc1Injector created.");
        }
        else {
            e.unmatchdMapViewProc1Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: CurveText fetch site (see the hook comment
        // above). The pattern covers the fetch, the glyph load, the
        // null test and the R15 reload; the patch is 17 bytes and
        // returns at the je on a null glyph.
        BytePattern.tempInstance().findPattern("0F B6 00 4D 8B 2C C4 4D 85 ED 4C 8B BD F8 FE FF FF 0F 84 3D 07 00 00");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ２の文字取得処理 (v1.37.5 CurveText)")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            mapViewProc1V137ReturnAddress = address + 17;
            mapViewGlyphLookupFuncAddress = cast(size_t) &wideGlyphLookup;

            PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapViewProc1V137CurveText_hook, 17);
            writeln("JMP for mapViewProc1Injector (v1.37.5 CurveText) created.");
        }
        else {
            e.unmatchdMapViewProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionMapViewProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError mapViewProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_1_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0: {
        // lea     r9, [r12+100h]
        BytePattern.tempInstance().findPattern("4D 8D 8C 24 00 01 00 00 42 0F B6 04 38 4D 8B 24 C1");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字取得処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // test    r12, r12
            mapViewProc2ReturnAddress = address + 0x11;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapViewProc2));
            writeln("JMP for mapViewProc2Injector (v1_29_X) created.");
        }
        else {
            e.unmatchdMapViewProc2Injector = true;
        }
        break;
    }
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
    case EU4Ver.v1_33_3_0: {
        // lea     r9, [r12+120h]
        BytePattern.tempInstance().findPattern("4D 8D 8C 24 20 01 00 00 42 0F B6 04 38 4D 8B 24 C1");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字取得処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // test    r12, r12
            mapViewProc2ReturnAddress = address + 0x11;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapViewProc2V130));
            writeln("JMP for mapViewProc2Injector (v1_30_X_plus) created.");
        }
        else {
            e.unmatchdMapViewProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: the loop-1 counting fetches live in
        // AddNameArea and in AddNudgedNames (see the hook comment
        // above). Each patch is 14 bytes (fetch + glyph load +
        // null test) and returns at the je on a null glyph.
        BytePattern.tempInstance().findPattern("0F B6 00 49 8B 84 C4 00 01 00 00 48 85 C0 74 0D 31 C9 66 83 78 06 00 0F 9F C1");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字取得処理 (v1.37.5 AddNameArea)")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            mapViewProc2V137AddNameAreaReturnAddress = address + 14;
            mapViewGlyphLookupFuncAddress = cast(size_t) &wideGlyphLookup;

            PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapViewProc2V137AddNameAreaCount_hook, 14);
            writeln("JMP for mapViewProc2Injector (v1.37.5 AddNameArea) created.");
        }
        else {
            e.unmatchdMapViewProc2Injector = true;
        }

        BytePattern.tempInstance().findPattern("0F B6 00 49 8B 84 C4 00 01 00 00 48 85 C0 74 14 31 C9 66 83 78 06 00 0F 9F C1");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字取得処理 (v1.37.5 AddNudgedNames)")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            mapViewProc2V137AddNudgedReturnAddress = address + 14;
            mapViewGlyphLookupFuncAddress = cast(size_t) &wideGlyphLookup;

            PatchManager.instance().addJmpPatch(cast(void*)address, cast(void*)&mapViewProc2V137AddNudgedCount_hook, 14);
            writeln("JMP for mapViewProc2Injector (v1.37.5 AddNudgedNames) created.");
        }
        else {
            e.unmatchdMapViewProc2Injector = true;
        }
        break;
    }
    default: {
        e.versionMapViewProc2Injector = true;
        break;
    }
    }

    return e;
}

DllError mapViewProc3Injector(RunOptions options) {
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
        // movzx   r8d, byte ptr [rax+r15]
        BytePattern.tempInstance().findPattern("46 0F B6 04 38 BA 01 00 00 00 48 8D 4C 24 40");
        if (BytePattern.tempInstance().hasSize(1, "処理ループ１の文字コピー")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx}
            mapViewProc3CallAddress = address + 0x0F + get_branch_destination_offset(cast(void*)(address + 0x0F), 4); // 仮のアドレス

            // nop
            mapViewProc3ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)mapViewProc3));
            writeln("JMP for mapViewProc3Injector created.");
        }
        else {
            e.unmatchdMapViewProc3Injector = true;
        }
        break;
    }
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5: there is no separate character-copy loop
        // in the map name path. The one place that copies the name
        // character by character is the letter-spacing construction
        // inside AddNameArea, and that is hooked by MapJustify
        // (plugin.map_justify proc1 v1.37.5). Nothing to patch here.
        break;
    }
    default: {
        e.versionMapViewProc3Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | mapViewProc1Injector(options);
    result = result | mapViewProc2Injector(options);
    result = result | mapViewProc3Injector(options);

    return result;
}
