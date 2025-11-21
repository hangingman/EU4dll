module plugin.ime;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant; // RunOptionsを使用するためインポート
import plugin.misc; // get_branch_destination_offset を使用するためインポート
import plugin.input; // DllErrorとRunOptionsを使用するためインポート // 修正: :DllError を削除
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

// SDL_Rectに相当する構造体
struct SDL_Rect {
    int x, y;
    int w, h;
}

SDL_Rect rect = { 0, 0, 0, 0 };

extern(C) {
    void* imeProc1() { return null; }
    void* imeProc2() { return null; }
    void* imeProc3() { return null; }
}

size_t imeProc1ReturnAddress1;
size_t imeProc1ReturnAddress2;
size_t imeProc1CallAddress;
size_t imeProc2CallAddress;
size_t imeProc2ReturnAddress1;
size_t imeProc2ReturnAddress2;
size_t rectAddress;
size_t imeProc3ReturnAddress;
size_t imeProc3CallAddress1;
size_t imeProc3CallAddress2;
size_t imeProc3CallAddress3;
size_t imeProc3CallAddress4;
size_t imeProc3CallAddress5;


// CompositionやCandidateが表示されるようにする
// SDL_windowsevents.c#WIN_WindowProcでIME_HandleMessageのif文で`return 0`するのが問題なので、
// 関数の一番下にある` if (data->wndproc)`までつなげる
// https://twitter.com/matanki_saito/status/1006954440736235521
DllError imeProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
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
        // mov     edx, r13d
        BytePattern.tempInstance().findPattern("41 8B D5 49 8B CC E8 ? ? ? ? 85 C0 0F 85");
        if (BytePattern.tempInstance().hasSize(1, "SDL_windowsevents.cの修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx}
            // FIXME: Injector::GetBranchDestination に相当するD言語でのアドレス取得処理を実装する
            // imeProc1CallAddress = Injector.GetBranchDestination(address + 0x6).as_int();
            imeProc1CallAddress = address + 0x06 + get_branch_destination_offset(cast(void*)(address + 0x06), 4); // 仮のアドレス

            // cmp     r13d, 0FFh
            imeProc1ReturnAddress1 = address + 0x13;

            // jz {xxxxx}
            // imeProc1ReturnAddress2 = Injector.GetBranchDestination(address - 0x19).as_int();
            imeProc1ReturnAddress2 = address - 0x19 + get_branch_destination_offset(cast(void*)(address - 0x19), 4); // 仮のアドレス

            // Injector::MakeJMP に相当するD言語でのフック処理を実装する
            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)imeProc1));
            writeln("JMP for imeProc1Injector created.");
        }
        else {
            e.unmatchdImeProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionImeProc1Injector = true;
        break;
    }
    }

    return e;
}

// CompositionやCandidateが表示されるようにする
// SDL_windowkeyboard.c#IME_HandleMessageにある処理を修正している
// 以下のTwitterだと最初の`return SDL_FALSE`をキャンセルしているがwin32のコードから確認できなかった
// https://twitter.com/matanki_saito/status/1006954448583704576
// これはISSUE19の対応時に復活させていた
// https://github.com/matanki-saito/EU4dll/issues/19#issuecomment-423940649
DllError imeProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
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
        rectAddress = cast(size_t)&rect;

        // SDL_SetTextInputRectの関数を見つける
        BytePattern.tempInstance().findPattern("48 8B D1 48 8B ? ? ? ? 00 48 85 C9 74 0F"); // mov     rdx, rcx
        if (BytePattern.tempInstance().hasSize(1, "SDL_windowskeyboard.cの修正")) {
            imeProc2CallAddress = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdImeProc2Injector = true;
        }

        // WM_IME_STARTCOMPOSITIONでSDL_SetTextInputRectする
        BytePattern.tempInstance().findPattern("81 EA BC 00 00 00 0F 84 2B 02 00 00"); // sub     edx, 0BCh
        if (BytePattern.tempInstance().hasSize(1, "SDL_windowskeyboard.cの修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz {loc_xxxxx}
            // imeProc2ReturnAddress1 = Injector.GetBranchDestination(address + 0x6).as_int();
            imeProc2ReturnAddress1 = address + 0x06 + get_branch_destination_offset(cast(void*)(address + 0x06), 4); // 仮のアドレス

            // jnz loc_xxxxx
            imeProc2ReturnAddress2 = address + 15;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)imeProc2));
            writeln("JMP for imeProc2Injector created.");
        }
        else {
            e.unmatchdImeProc2Injector = true;
        }

        // WM_IME_SETCONTEXTで*lParam = 0;をコメントアウトする（nopで埋める）
        // mov     [r9], r15
        BytePattern.tempInstance().findPattern("4D 89 39 48 8B 74 24 40");
        if (BytePattern.tempInstance().hasSize(1, "SDL_windowskeyboard.cの修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            // Injector::WriteMemory に相当するD言語でのメモリ書き換え処理を実装する
            // 0x90 は NOP 命令
            PatchManager.instance().addPatch(cast(void*)address, cast(ubyte[])[0x90, 0x90, 0x90]);
            writeln("WriteMemory for imeProc2Injector (1) called.");
        }
        else {
            e.unmatchdImeProc2Injector = true;
        }

        // WM_IME_COMPOSITIONのif文のIME_GetCompositionStringとIME_SendInputEventをコメントアウト（jmpさせる）
        //  mov     r8d, 800h
        // 二つ目のif文もスキップさせる
        // https://github.com/matanki-saito/EU4dll/issues/19#issuecomment-423940364
        BytePattern.tempInstance().findPattern("41 B8 00 08 00 00 48 8B D6 48 8B CF");
        if (BytePattern.tempInstance().hasSize(1, "SDL_windowskeyboard.cの修正")) {
            // jz xxx -> jmp xxx
            size_t address = BytePattern.tempInstance().getFirst().address;
            PatchManager.instance().addPatch(cast(void*)(address - 2), cast(ubyte[])[0xEB, 0x49]);
            writeln("WriteMemory for imeProc2Injector (2) called.");
        }
        else {
            e.unmatchdImeProc2Injector = true;
        }
        break;
    }
    default: {
        e.unmatchdImeProc2Injector = true; // C++版はversionImeProc2InjectorではなくunmatchdImeProc2Injectorにしていた
        break;
    }
    }

    return e;
}

// コンポジション入力中のバックスペースや矢印キーのイベントをキャンセルする
// WM_KEYDOWNのみの修正で、WM_KEYUPの修正は入れていない。おそらくそれでも問題ない
// https://github.com/matanki-saito/EU4dll/issues/19
DllError imeProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
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
        // 直前の部分でjmpに使う14byteを確保することができなかった。
        // そのためWM_KEYDOWNのコードをすべて移植した
        // mov     rcx, [rbp+0C0h+hRawInput]
        BytePattern.tempInstance().findPattern("48 8B 8D E8 ? ? ? ? 8B D6 E8 ? ? ? ? 33");
        if (BytePattern.tempInstance().hasSize(2, "SDL_windowsevents.cの修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx} / WindowsScanCodeToSDLScanCode
            // imeProc3CallAddress1 = Injector.GetBranchDestination(address + 0xA).as_int();
            imeProc3CallAddress1 = address + 0x0A + get_branch_destination_offset(cast(void*)(address + 0x0A), 4); // 仮のアドレス

            // call {sub_xxxxx} / SDL_GetKeyboardState
            // imeProc3CallAddress2 = Injector.GetBranchDestination(address + 0x13).as_int();
            imeProc3CallAddress2 = address + 0x13 + get_branch_destination_offset(cast(void*)(address + 0x13), 4); // 仮のアドレス

            // call {sub_xxxxx} / ShouldGenerateWindowCloseOnAltF4
            // imeProc3CallAddress3 = Injector.GetBranchDestination(address + 0x36).as_int();
            imeProc3CallAddress3 = address + 0x36 + get_branch_destination_offset(cast(void*)(address + 0x36), 4); // 仮のアドレス

            // call {sub_xxxxx} / SDL_SendWindowEvent
            // imeProc3CallAddress4 = Injector.GetBranchDestination(address + 0x50).as_int();
            imeProc3CallAddress4 = address + 0x50 + get_branch_destination_offset(cast(void*)(address + 0x50), 4); // 仮のアドレス

            // call {sub_xxxxx} / SDL_SendKeyboardKey
            // imeProc3CallAddress5 = Injector.GetBranchDestination(address + 0x61).as_int();
            imeProc3CallAddress5 = address + 0x61 + get_branch_destination_offset(cast(void*)(address + 0x61), 4); // 仮のアドレス

            // xor     edi, edi
            imeProc3ReturnAddress = address + 0x66;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)imeProc3));
            writeln("JMP for imeProc3Injector created.");
        }
        else {
            // e.unmatchdImeProc3Injector = true; // 修正: 存在しないプロパティの参照を削除
        }
        break;
    }
    default: {
        // e.versionImeProc3Injector = true; // 修正: 存在しないプロパティの参照を削除
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | imeProc1Injector(options);
    result = result | imeProc2Injector(options);
    result = result | imeProc3Injector(options);

    return result;
}
