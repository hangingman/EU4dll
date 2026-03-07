module plugin.main_text;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
 // @naked を使用するため

// 対策3: __gshared必須、一時的なコードポイントを格納
// mainTextProc2TmpCharacter	DD	0 に相当
private __gshared uint s_lastCodePoint = 0;

// ASMで定義されている定数
enum ESCAPE_SEQ_1 = 0x10;
enum ESCAPE_SEQ_2 = 0x11;
enum ESCAPE_SEQ_3 = 0x12;
enum ESCAPE_SEQ_4 = 0x13;
enum LOW_SHIFT = 0x0E;
enum HIGH_SHIFT = 0x09;
enum SHIFT_2 = LOW_SHIFT;
enum SHIFT_3 = 0x900;
enum SHIFT_4 = 0x8F2;
enum NO_FONT = 0x98F;
enum NOT_DEF = 0x2026;

extern (C)
{
    // mainTextProc1 PROC
    void mainTextProc1_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                mov       EAX, EDI;
                shl       RAX, 32;
                sar       RAX, 32; // 32bitから64bitへの符号拡張を明示的に (LDC/DMD iasm互換性のための手動実装)

                cmp       byte ptr [RAX + RBX], ESCAPE_SEQ_1;
                jz        JMP_A;
                cmp       byte ptr [RAX + RBX], ESCAPE_SEQ_2;
                jz        JMP_B;
                cmp       byte ptr [RAX + RBX], ESCAPE_SEQ_3;
                jz        JMP_C;
                cmp       byte ptr [RAX + RBX], ESCAPE_SEQ_4;
                jz        JMP_D;
                movzx     EAX, byte ptr [RAX+RBX];
                jmp       JMP_E;

            JMP_A:
                movzx     EAX, word ptr [RAX + RBX + 1];
                jmp       JMP_F;

            JMP_B:
                movzx     EAX, word ptr [RAX + RBX + 1];
                sub       EAX, SHIFT_2;
                jmp       JMP_F;

            JMP_C:
                movzx     EAX, word ptr [RAX + RBX + 1];
                add       EAX, SHIFT_3;
                jmp       JMP_F;

            JMP_D:
                movzx     EAX, word ptr [RAX + RBX + 1];
                add       EAX, SHIFT_4;

            JMP_F:
                movzx     EAX, AX;
                add       EDI, 2;
                cmp       EAX, NO_FONT;

                ja        JMP_E;
                mov       EAX, NOT_DEF;
            JMP_E:
                movss     XMM3, dword ptr [R15+0x848];
                mov       RBX, qword ptr [R15+RAX*8];
                mov       qword ptr [RBP+0x100], RBX;

                lea       R11, [RIP + mainTextProc1ReturnAddress]; // LEAでアドレスをロード
                jmp       qword ptr [R11]; // ロードしたアドレスにジャンプ
            }
        }
    }

    // mainTextProc2 PROC (v1_29_1_0 to v1_30_5_0)
    void mainTextProc2_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                mov       EDX, EDI;
                shl       RDX, 32;
                sar       RDX, 32;
                mov       ECX, R14D;
                shl       RCX, 32;
                sar       RCX, 32;
                mov       R10, qword ptr [RSP + 0x78]; // RSP+858h-7E0h = RSP+78h

                movzx     EAX, byte ptr [RDX+R10];
                lea       R9, [RIP + mainTextProc2BufferAddress]; // LEAでアドレスをロード
                mov       R9, qword ptr [R9]; // グローバル変数の値をR9にロード
                mov       byte ptr [RCX+R9], AL;

                inc       R14D;
                inc       RCX;

                cmp       AL, ESCAPE_SEQ_1;
                jz        JMP_A;
                cmp       AL, ESCAPE_SEQ_2;
                jz        JMP_B;
                cmp       AL, ESCAPE_SEQ_3;
                jz        JMP_C;
                cmp       AL, ESCAPE_SEQ_4;
                jz        JMP_D;
                jmp       JMP_E;

            JMP_A:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                jmp       JMP_F;

            JMP_B:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                sub       EAX, SHIFT_2;
                jmp       JMP_F;

            JMP_C:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                add       EAX, SHIFT_3;
                jmp       JMP_F;

            JMP_D:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                add       EAX, SHIFT_4;

            JMP_F:
                movzx     EAX, AX;
                add       R14D, 2;
                add       RCX, 2;
                cmp       EAX, NO_FONT;

                ja        JMP_G;
                mov       EAX, NOT_DEF;

            JMP_G:
                add       RDX, 2;
                add       EDI, 2;
            JMP_E:
                lea       R11, [RIP + s_lastCodePoint]; // LEAでアドレスをロード
                mov       dword ptr [R11], EAX; // 対策3: __gshared変数に保存
                
                lea       R11, [RIP + mainTextProc2ReturnAddress]; // LEAでアドレスをロード
                jmp       qword ptr [R11]; // ロードしたアドレスにジャンプ
            }
        }
    }

    // mainTextProc2 PROC (v1_31_1_0 to v1_33_3_0)
    void mainTextProc2_v131_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                // Original assembly for v1.31.x starts with:
                // movsxd  rdx, edi
                // movsxd  rcx, r14d
                // mov     r10, qword ptr [rsp+80h]
                naked;
                mov       EDX, EDI;
                shl       RDX, 32;
                sar       RDX, 32;
                mov       ECX, R14D;
                shl       RCX, 32;
                sar       RCX, 32;
                mov       R10, qword ptr [RSP + 0x78]; // RSP+858h-7E0h = RSP+78h

                movzx     EAX, byte ptr [RDX+R10];
                lea       R9, [RIP + mainTextProc2BufferAddress]; // LEAでアドレスをロード
                mov       R9, qword ptr [R9]; // グローバル変数の値をR9にロード
                mov       byte ptr [RCX+R9], AL;

                inc       R14D;
                inc       RCX;

                cmp       AL, ESCAPE_SEQ_1;
                jz        JMP_A;
                cmp       AL, ESCAPE_SEQ_2;
                jz        JMP_B;
                cmp       AL, ESCAPE_SEQ_3;
                jz        JMP_C;
                cmp       AL, ESCAPE_SEQ_4;
                jz        JMP_D;
                jmp       JMP_E;

            JMP_A:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                jmp       JMP_F;

            JMP_B:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                sub       EAX, SHIFT_2;
                jmp       JMP_F;

            JMP_C:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                add       EAX, SHIFT_3;
                jmp       JMP_F;

            JMP_D:
                movzx     EAX, word ptr [RDX+R10+1];
                mov       word ptr [RCX+R9], AX;
                add       EAX, SHIFT_4;

            JMP_F:
                movzx     EAX, AX;
                add       R14D, 2;
                add       RCX, 2;
                cmp       EAX, NO_FONT;

                ja        JMP_G;
                mov       EAX, NOT_DEF;

            JMP_G:
                add       RDX, 2;
                add       EDI, 2;
            JMP_E:
                lea       R11, [RIP + s_lastCodePoint]; // LEAでアドレスをロード
                mov       dword ptr [R11], EAX; // 対策3: __gshared変数に保存
                
                lea       R11, [RIP + mainTextProc2ReturnAddress]; // LEAでアドレスをロード
                jmp       qword ptr [R11]; // ロードしたアドレスにジャンプ
            }
        }
    }

    // mainTextProc3 PROC
    void mainTextProc3_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                cmp word ptr[RCX + 6], 0;
                jnz JMP_A;
                jmp JMP_B;

            JMP_A:
                cmp dword ptr [RIP + s_lastCodePoint], 0xFF; // 対策3: __gshared変数から読み込み
                ja JMP_B;

                mov R11, qword ptr[RIP + mainTextProc3ReturnAddress2];
                jmp R11;

            JMP_B:
                lea EAX, dword ptr[RBX + RBX];
                movd XMM1, EAX;

                mov R11, qword ptr[RIP + mainTextProc3ReturnAddress1];
                jmp R11;
            }
        }
    }

    // mainTextProc4 PROC
    void mainTextProc4_hook()
    {
        version (X86_64)
        {
            asm
            {
                naked;
                // check code point saved proc1
                cmp dword ptr [RIP + s_lastCodePoint], 0xFF; // 対策3: __gshared変数から読み込み
                ja JMP_A;

                movzx EAX, byte ptr[RDX + R10]; // Original instruction
                jmp JMP_B;

            JMP_A:
                mov EAX, dword ptr [RIP + s_lastCodePoint]; // 対策3: __gshared変数から読み込み

            JMP_B:
                mov RCX, qword ptr[R15 + RAX * 8];
                mov qword ptr[RBP - 0x60], RCX;
                test RCX, RCX;

                mov R11, qword ptr[RIP + mainTextProc4ReturnAddress];
                jmp R11;
            }
        }
    }
}

private __gshared size_t mainTextProc1ReturnAddress;
private __gshared size_t mainTextProc2ReturnAddress;
private __gshared size_t mainTextProc2BufferAddress;
private __gshared size_t mainTextProc3ReturnAddress1;
private __gshared size_t mainTextProc3ReturnAddress2;
private __gshared size_t mainTextProc4ReturnAddress;
// mainTextProc4ReturnAddress_after_movzx_eax は C++版には存在しないため削除
// mainTextProcCopyBuffReturnAddress も C++版には存在しないため削除

DllError mainTextProc1Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
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
    case EU4Ver.v1_33_3_0:
        {
            // movsxd rax, edi
            BytePattern.tempInstance()
                .findPattern("48 63 C7 0F B6 04 18 F3 41 0F 10 9F 48 08 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ２の文字取得修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // movss dword ptr [rpb+108h], xmm3
                mainTextProc1ReturnAddress = address + 0x1B;

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc1_hook));
                writeln("JMP for mainTextProc1Injector created.");
            }
            else
            {
                e.unmatchdMainTextProc1Injector = true;
            }
            break;
        }
    default:
        {
            e.versionMainTextProc1Injector = true;
            break;
        }
    }

    return e;
}

DllError mainTextProc2Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_33_3_0:
        {
            // movsxd rdx, edi
            BytePattern.tempInstance().findPattern("48 63 D7 49 63 CE 4C 8B 55 80");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１のカウント処理修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cmp byte ptr [rbp+750h+arg_50],0
                mainTextProc2ReturnAddress = address + 0x1D;

                // lea r9, {unk_XXXXX}
                mainTextProc2BufferAddress = address + 0x0F + get_branch_destination_offset(
                    cast(void*)(address + 0x0F), 4); // 仮のアドレス

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc2_v131_hook));
                writeln("JMP for mainTextProc2Injector (v131) created.");
            }
            else
            {
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
    case EU4Ver.v1_30_5_0:
        {
            // movsxd rdx, edi
            BytePattern.tempInstance().findPattern("48 63 D7 49 63 CE 4C 8B 54 24 78");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１のカウント処理修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cmp byte ptr [rbp+7B0h],0
                mainTextProc2ReturnAddress = address + 0x1E;

                // lea r9, {unk_XXXXX}
                mainTextProc2BufferAddress = address + 0x10 + get_branch_destination_offset(
                    cast(void*)(address + 0x10), 4); // 仮のアドレス

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc2_hook));
                writeln("JMP for mainTextProc2Injector created.");
            }
            else
            {
                e.unmatchdMainTextProc2Injector = true;
            }
            break;
        }
    default:
        {
            e.versionMainTextProc2Injector = true;
            break;
        }
    }

    return e;
}

DllError mainTextProc3Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
        {
            // cmp cs:byte_xxxxx, 0
            BytePattern.tempInstance().findPattern("80 3D ? ? ? ? 00 0F 84 9A 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理の戻り先２取得"))
            {
                mainTextProc3ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
            }
            else
            {
                e.unmatchdMainTextProc3Injector = true;
            }

            // cmp word ptr [rcx+6],0
            BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 16 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理を修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cvtdq2ps xmm1,xmm1
                mainTextProc3ReturnAddress1 = address + 0x12;

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc3_hook));
                writeln("JMP for mainTextProc3Injector (v133) created.");
            }
            else
            {
                e.unmatchdMainTextProc3Injector = true;
            }
            break;
        }

    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
        {
            // cmp cs:byte_xxxxx, 0
            BytePattern.tempInstance().findPattern("80 3D ? ? ? ? 00 0F 84 97 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理の戻り先２取得"))
            {
                mainTextProc3ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
            }
            else
            {
                e.unmatchdMainTextProc3Injector = true;
            }

            // cmp word ptr [rcx+6],0
            BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 16 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理を修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cvtdq2ps xmm1,xmm1
                mainTextProc3ReturnAddress1 = address + 0x12;

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc3_hook));
                writeln("JMP for mainTextProc3Injector (v131) created.");
            }
            else
            {
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
    case EU4Ver.v1_30_5_0:
        {
            // cmp cs:byte_xxxxx, 0
            BytePattern.tempInstance().findPattern("80 3D ? ? ? ? 00 0F 84 97 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理の戻り先２取得"))
            {
                mainTextProc3ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
            }
            else
            {
                e.unmatchdMainTextProc3Injector = true;
            }

            // cmp word ptr [rcx+6],0
            BytePattern.tempInstance().findPattern("66 83 79 06 00 0F 85 15 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の改行処理を修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // cvtdq2ps xmm1,xmm1
                mainTextProc3ReturnAddress1 = address + 0x12;

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc3_hook));
                writeln("JMP for mainTextProc3Injector created.");
            }
            else
            {
                e.unmatchdMainTextProc3Injector = true;
            }
            break;
        }
    default:
        {
            e.versionMainTextProc3Injector = true;
            break;
        }
    }

    return e;
}

DllError mainTextProc4Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
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
    case EU4Ver.v1_33_3_0:
        {
            // movzx eax, byte ptr [rdx+r10]
            BytePattern.tempInstance().findPattern("42 0F B6 04 12 49 8B 0C C7");
            if (BytePattern.tempInstance().hasSize(1, "テキスト処理ループ１の文字取得修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // jz loc_xxxxx
                mainTextProc4ReturnAddress = address + 0x10;
                // mainTextProc4ReturnAddress_after_movzx_eax は C++版には存在しないため削除

                PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                        void*)&mainTextProc4_hook));
                writeln("JMP for mainTextProc4Injector created.");
            }
            else
            {
                e.unmatchdMainTextProc4Injector = true;
            }
            break;
        }
    default:
        {
            e.versionMainTextProc4Injector = true;
            break;
        }
    }

    return e;
}

DllError mainTextProcCopyBuffInjector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
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
    case EU4Ver.v1_33_3_0:
        {
            // Pattern for "copy text to buffer" (from C++ v1.28.3 Text.cpp)
            BytePattern.tempInstance().findPattern("42 80 7B 3C 00 8B 45 E8");
            if (BytePattern.tempInstance().hasSize(1, "テキストをバッファにコピー修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // mainTextProcCopyBuffReturnAddress = address + 0x5; // After the overwritten "cmp byte ptr [rbx+3Ch], 0" (5 bytes) // C++版には存在しないため削除

                // PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)&mainTextProcCopyBuff_hook)); // C++版には存在しないため削除
                // writeln("JMP for mainTextProcCopyBuffInjector created."); // C++版には存在しないため削除
            }
            else
            {
                e.unmatchdMainTextProcCopyBuffInjector = true;
            }
            break;
        }
    default:
        {
            e.versionMainTextProcCopyBuffInjector = true;
            break;
        }
    }

    return e;
}

DllError init(EU4Ver eu4Version)
{
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | mainTextProc1Injector(options);
    result = result | mainTextProc2Injector(options);
    result = result | mainTextProc3Injector(options);
    result = result | mainTextProc4Injector(options);
    // result = result | mainTextProcCopyBuffInjector(options); // C++版には存在しないため削除

    return result;
}
