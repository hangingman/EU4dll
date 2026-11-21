module plugin.font;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp;
import plugin.glyph_table : wideGlyphLookup, wideGlyphRegister; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

extern(C) {
    void* fontBufferHeapZeroClear() { return null; }
}

size_t fontBufferHeapZeroClearReturnAddress;
size_t fontBufferHeapZeroClearHeepAllocJmpAddress;
size_t fontBufferHeapZeroClearHeapJmpAddress;

DllError charCodePointLimiterPatchInjector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_0_0:
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
        /* 1.33.0.0 betaで初めて確認された */
        break;

    case EU4Ver.v1_37_5: {
        // Linux v1.37.5, CBitmapFont::ParseFontFile (VA 0x204e366):
        //   41 81 FD FF 00 00 00   cmp r13d, 0FFh
        //   0F 87 25 01 00 00      ja  +0x125 (skip glyph registration)
        // Pattern derived in item 12 (font_linux_patterns.md): exactly
        // 1 hit in the whole binary; the cmp alone has 23 hits, so the
        // ja displacement must be part of the pattern. Widening the
        // limit works like the Windows case below: the immediate is
        // FF 00 00 00 at pattern offset 3, so writing 0xFF at offset 4
        // (the second immediate byte) changes it to FF FF 00 00,
        // i.e. cmp r13d, 0FFFFh. hasSize(1) gates the patch: when the
        // count is not exactly 1 nothing is patched.
        BytePattern.tempInstance().findPattern("41 81 FD FF 00 00 00 0F 87 25 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "Char Code Point Limiter")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            PatchManager.instance().addPatch(cast(void*)(address + 4), cast(ubyte[])[0xFF]);
            writeln("WriteMemory for charCodePointLimiterPatchInjector (v1.37.5) called.");
        }
        else {
            e.unmatchdCharCodePointLimiterPatchInjector = true;
        }
        break;
    }
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // cmp     edi, 0FFh
        // 81 FF FF 00 00 00
        BytePattern.tempInstance().findPattern("81 FF FF 00 00 00 0F 87 2C 01 00 00 83");
        if (BytePattern.tempInstance().hasSize(1, "Char Code Point Limiter")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            // Injector::WriteMemory に相当するD言語でのメモリ書き換え処理を実装する
            PatchManager.instance().addPatch(cast(void*)(address + 3), cast(ubyte[])[0xFF]); // 修正: [0xFF]をcast(ubyte[])[0xFF]に
            writeln("WriteMemory for charCodePointLimiterPatchInjector called.");
        }
        else {
            e.unmatchdCharCodePointLimiterPatchInjector = true;
        }
        break;
    }
    default: {
        e.versionCharCodePointLimiterPatchInjector = true;
        break;
    }
    }

    return e;
}


// ---------------------------------------------------------------------------
// Item 28 step 2: ParseFontFile registration redirect (Linux v1.37.5).
//
// Duplicate check VA 0x204e385 and glyph store VA 0x204e55e (patched span
// starts 8 bytes before the store instruction at 0x204e563 so the 18-byte
// patch covers exactly three whole instructions and ends at 0x204e570,
// whose instruction is an entry point from another branch and must stay).
// For ids < 0x100 both trampolines reproduce the original instructions;
// for ids >= 0x100 they go through the side table in plugin.glyph_table.
// Design: memory-bank/details/glyph_table_expansion_item28.md
// ---------------------------------------------------------------------------

private __gshared size_t glyphDuplicateEmptyReturnAddress;
private __gshared size_t glyphDuplicateOccupiedReturnAddress;
private __gshared size_t glyphStoreReturnAddress;
private __gshared size_t glyphLookupFuncAddress;
private __gshared size_t glyphRegisterFuncAddress;

extern (C)
{
    // At entry: RAX = font base, RCX = zero-extended char id (from R13D).
    // Original: cmpq $0,0x100(%rax,%rcx,8); je empty(0x204e527)
    //           fallthrough occupied(0x204e394, Duplicate log path)
    void glyphDuplicateCheck_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                cmp ECX, 0x100;
                jb VANILLA;
                push RAX;
                push RCX;
                mov RDI, RAX;
                mov ESI, ECX;
                lea R11, [RIP + glyphLookupFuncAddress];
                mov R11, qword ptr [R11];
                call R11;
                mov R11, RAX;
                pop RCX;
                pop RAX;
                test R11, R11;
                jz EMPTY;
                lea R11, [RIP + glyphDuplicateOccupiedReturnAddress];
                jmp qword ptr [R11];
            EMPTY:
                lea R11, [RIP + glyphDuplicateEmptyReturnAddress];
                jmp qword ptr [R11];
            VANILLA:
                cmp qword ptr [RAX + RCX*8 + 0x100], 0;
                jz EMPTY;
                lea R11, [RIP + glyphDuplicateOccupiedReturnAddress];
                jmp qword ptr [R11];
            }
        }
    }

    // At entry (patch start VA 0x204e55e): RAX = new glyph pointer,
    // R13 = char id (zero-extended at 0x204e527), font base at 0x8(%rsp).
    // Original span: mov 0x8(%rsp),%rcx; mov %rax,0x100(%rcx,%r13,8);
    //                jmp 0x204e0aa (loop head)
    void glyphStore_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                mov RCX, qword ptr [RSP + 0x8];
                cmp R13, 0x100;
                jb VANILLA;
                push RAX;
                push RCX;
                push R13;
                push R11;
                mov RDI, RCX;
                mov ESI, R13D;
                mov RDX, RAX;
                lea R11, [RIP + glyphRegisterFuncAddress];
                mov R11, qword ptr [R11];
                call R11;
                pop R11;
                pop R13;
                pop RCX;
                pop RAX;
                lea R11, [RIP + glyphStoreReturnAddress];
                jmp qword ptr [R11];
            VANILLA:
                mov qword ptr [RCX + R13*8 + 0x100], RAX;
                lea R11, [RIP + glyphStoreReturnAddress];
                jmp qword ptr [R11];
            }
        }
    }
}

DllError glyphDuplicateCheckInjector(RunOptions options)
{
    DllError e;
    switch (options.eu4Version)
    {
    case EU4Ver.v1_37_5:
        {
            // VA 0x204e385: cmpq $0,0x100(%rax,%rcx,8) (9 bytes)
            //               je 0x204e527 (6 bytes) = 15-byte patch span.
            BytePattern.tempInstance().findPattern(
                "48 83 BC C8 00 01 00 00 00 0F 84 93 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "Glyph duplicate check"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;
                glyphDuplicateEmptyReturnAddress = address + 0x1A2; // 0x204e527
                glyphDuplicateOccupiedReturnAddress = address + 0xF; // 0x204e394
                glyphLookupFuncAddress = cast(size_t) &wideGlyphLookup;
                PatchManager.instance().addJmpPatch(cast(void*) address,
                    cast(void*) &glyphDuplicateCheck_hook, 15);
                writeln("JMP for glyphDuplicateCheckInjector (v1.37.5) called.");
            }
            else
            {
                e.unmatchdGlyphDuplicateCheckInjector = true;
            }
            break;
        }
    default:
        {
            e.versionGlyphDuplicateCheckInjector = true;
            break;
        }
    }
    return e;
}

DllError glyphStoreInjector(RunOptions options)
{
    DllError e;
    switch (options.eu4Version)
    {
    case EU4Ver.v1_37_5:
        {
            // VA 0x204e55e: mov 0x8(%rsp),%rcx (5 bytes)
            //               mov %rax,0x100(%rcx,%r13,8) (8 bytes, at 0x204e563)
            //               jmp 0x204e0aa (5 bytes) = 18-byte patch span,
            //               ending exactly at 0x204e570.
            BytePattern.tempInstance().findPattern(
                "48 8B 4C 24 08 4A 89 84 E9 00 01 00 00 E9 3A FB FF FF");
            if (BytePattern.tempInstance().hasSize(1, "Glyph store"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;
                glyphStoreReturnAddress = address - 0x4B4; // 0x204e0aa
                glyphRegisterFuncAddress = cast(size_t) &wideGlyphRegister;
                PatchManager.instance().addJmpPatch(cast(void*) address,
                    cast(void*) &glyphStore_hook, 18);
                writeln("JMP for glyphStoreInjector (v1.37.5) called.");
            }
            else
            {
                e.unmatchdGlyphStoreInjector = true;
            }
            break;
        }
    default:
        {
            e.versionGlyphStoreInjector = true;
            break;
        }
    }
    return e;
}

DllError fontBufferHeapZeroClearInjector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_0_0:
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
        // mov rcx,cs:hHeap
        BytePattern.tempInstance().findPattern("48 8B 0D ? ? ? ? 4C 8B C3 33 D2");
        if (BytePattern.tempInstance().hasSize(1, "Font buffer heap zero clear")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            
            // mov rcx, {cs:hHeap}
            // FIXME: Injector::GetBranchDestination に相当するD言語でのアドレス取得処理を実装する (必要であれば実装する)
            fontBufferHeapZeroClearHeapJmpAddress = address + 0x01; // 仮のアドレス

            fontBufferHeapZeroClearHeepAllocJmpAddress = address + 0x0D; // 仮のアドレス
            // jz short loc_xxxxx
            fontBufferHeapZeroClearReturnAddress = address + 0x15;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)fontBufferHeapZeroClear));
            writeln("JMP for fontBufferHeapZeroClearInjector called.");
        } else {
            e.unmatchdFontBufferHeapZeroClearInjector = true;
        }
        break;
    }
    default: {
        e.unmatchdFontBufferHeapZeroClearInjector = true;
        break;
    }
    }

    return e;
}

DllError fontBufferClear1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_0_0:
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
        BytePattern.tempInstance().findPattern("BA 88 3D 00 00 48 8B CF");
        if (BytePattern.tempInstance().hasSize(1, "Font buffer clear")) {
            // mov edx, 3D88h
            PatchManager.instance().addPatch(cast(void*)(BytePattern.tempInstance().getFirst().address + 0x3), cast(ubyte[])[0x10]); // 修正: [0x10]をcast(ubyte[])[0x10]に
            writeln("WriteMemory for fontBufferClear1Injector called.");
        }
        else {
            e.unmatchdFontBufferClear1Injector = true;
        }
        break;
    }
    default: {
        e.versionFontBufferClear1Injector = true;
        break;
    }
    }

    return e;
}

DllError fontBufferClear2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_0_0:
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
        BytePattern.tempInstance().findPattern("BA 88 3D 00 00 48 8B 4D 28");
        if (BytePattern.tempInstance().hasSize(1, "Font buffer clear")) {
            // mov edx, 3D88h
            PatchManager.instance().addPatch(cast(void*)(BytePattern.tempInstance().getFirst().address + 0x3), cast(ubyte[])[0x10]); // 修正: [0x10]をcast(ubyte[])[0x10]に
            writeln("WriteMemory for fontBufferClear2Injector called.");
        }
        else {
            e.unmatchdFontBufferClear2Injector = true;
        }
        break;
    }
    default: {
        e.versionFontBufferClear2Injector = true;
        break;
    }
    }

    return e;
}

DllError fontBufferExpansionInjector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_0_0:
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
        BytePattern.tempInstance().findPattern("B9 88 3D 00 00");
        if (BytePattern.tempInstance().hasSize(1, "Font buffer expansion")) {
            // mov ecx, 3D88h
            PatchManager.instance().addPatch(cast(void*)(BytePattern.tempInstance().getFirst().address + 0x3), cast(ubyte[])[0x10]); // 修正: [0x10]をcast(ubyte[])[0x10]に
            writeln("WriteMemory for fontBufferExpansionInjector called.");
        } else {
            e.unmatchdFontBufferExpansionInjector = true;
        }
        break;
    }
    default: {
        e.versionFontBufferExpansionInjector = true;
        break;
    }
    }
    
    return e;
}

DllError fontSizeLimitInjector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_37_5: {
        // Linux v1.37.5, CTextureHandler::LoadTexture (VA 0x22a7edb):
        //   81 FB 00 00 00 01   cmp ebx, 1000000h
        //   72 19               jb  +0x19 (read the file)
        // ebx is CVirtualFile::GetSize() of the texture being loaded;
        // at or above 16 MiB the load is rejected. This is the only
        // cmp with immediate 1000000h in any graphics/texture function
        // in the whole binary (item 18 re-search, see
        // memory-bank/details/font_remaining_linux_injectors.md):
        // the Windows pattern (41 81 FE ..., cmp r14d) has 0 hits and
        // the other masked-generic hits are in unrelated code (lua,
        // curl, OpenSSL, minidump, network protocol parsing, ...).
        // The short pattern alone is exactly 1 hit in the whole
        // binary; the extended pattern below keeps that guarantee if
        // a future build adds a second cmp ebx site. Patch semantics
        // mirror the Windows case: the immediate is 00 00 00 01 at
        // pattern offset 2, so writing 0x04 at offset 5 (its last
        // byte) changes the limit to 04000000h (64 MiB).
        BytePattern.tempInstance().findPattern("81 FB 00 00 00 01 72 19 BB 01 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "Font size limit")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            PatchManager.instance().addPatch(cast(void*)(address + 5), cast(ubyte[])[0x04]);
            writeln("WriteMemory for fontSizeLimitInjector (v1.37.5) called.");
        }
        else {
            e.unmatchdFontSizeLimitInjector = true;
        }
        break;
    }
    case EU4Ver.v1_29_0_0:
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
        BytePattern.tempInstance().findPattern("41 81 FE 00 00 00 01");
        if (BytePattern.tempInstance().hasSize(1, "Font size limit")) {
            // cmp r14d, 1000000h
            PatchManager.instance().addPatch(cast(void*)(BytePattern.tempInstance().getFirst().address + 0x6), cast(ubyte[])[0x04]); // 修正: [0x04]をcast(ubyte[])[0x04]に
            writeln("WriteMemory for fontSizeLimitInjector called.");
        } else {
            e.unmatchdFontSizeLimitInjector = true;
        }
        break;
    }
    default: {
        e.versionFontSizeLimitInjector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | charCodePointLimiterPatchInjector(options);
    result = result | fontBufferHeapZeroClearInjector(options);
    result = result | fontBufferClear1Injector(options);
    result = result | fontBufferClear2Injector(options);
    result = result | fontBufferExpansionInjector(options);
    result = result | fontSizeLimitInjector(options);
    result = result | glyphDuplicateCheckInjector(options);
    result = result | glyphStoreInjector(options);

    return result;
}
