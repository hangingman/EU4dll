module plugin.event_dialog;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

extern(C) {
    void* eventDialogProc1() { return null; }
    void* eventDialogProc1V132() { return null; }
    void* eventDialogProc2() { return null; }
    void* eventDialogProc3() { return null; }
    void* eventDialogProc3V130() { return null; }
    void* eventDialogProc3V132() { return null; }
}

size_t eventDialogProc1ReturnAddress;
size_t eventDialogProc2ReturnAddress1;
size_t eventDialogProc2ReturnAddress2;
size_t eventDialogProc3ReturnAddress;

DllError eventDialog1Injector(RunOptions options) {
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
        // movzx   eax, byte ptr [rcx+rax]
        BytePattern.tempInstance().findPattern("0F B6 04 01 49 8B 34 C2 F3 41 0F 10 8A 48 08 00 00");
        if (BytePattern.tempInstance().hasSize(1, "文字取得処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz      loc_xxxxx
            eventDialogProc1ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc1));
            writeln("JMP for eventDialog1Injector created.");
        }
        else {
            e.unmatchdEventDialog1Injector = true;
        }
        break;
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // movzx   eax, byte ptr [rdx+rax]
        BytePattern.tempInstance().findPattern("0F B6 04 02 49 8B 34 C2 F3 41 0F 10 8A 48 08 00 00");
        if (BytePattern.tempInstance().hasSize(1, "文字取得処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz      loc_xxxxx
            eventDialogProc1ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc1V132));
            writeln("JMP for eventDialog1Injector (v1_32_plus) created.");
        }
        else {
            e.unmatchdEventDialog1Injector = true;
        }
        break;
    default:
        e.versionEventDialog1Injector = true;
    }

    return e;
}

DllError eventDialog2Injector(RunOptions options) {
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
        // mov     rax, [rsp+378h+arg_20]
        BytePattern.tempInstance().findPattern("48 8B 84 24 A0 03 00 00 8B 00 03 C0");
        if (BytePattern.tempInstance().hasSize(1, "分岐処理修正戻り先アドレス２")) {
            eventDialogProc2ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdEventDialog2Injector = true;
        }

        // cvtdq2ps xmm0, xmm0
        BytePattern.tempInstance().findPattern("0F 5B C0 F3 0F 59 C1 41 0F 2E C0 7A 4D");
        if (BytePattern.tempInstance().hasSize(1, "分岐処理修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // movd    xmm0, [rsp+378h+arg_8]
            eventDialogProc2ReturnAddress1 = address + 0x0F;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc2));
            writeln("JMP for eventDialog2Injector created.");
        }
        else {
            e.unmatchdEventDialog2Injector = true;
        }
        break;
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // mov     rax, [rsp+1158h+arg_20]
        BytePattern.tempInstance().findPattern("48 8B 84 24 80 11 00 00 8B 00 03 C0");
        if (BytePattern.tempInstance().hasSize(1, "分岐処理修正戻り先アドレス２")) {
            eventDialogProc2ReturnAddress2 = BytePattern.tempInstance().getFirst().address;
        }
        else {
            e.unmatchdEventDialog2Injector = true;
        }

        // cvtdq2ps xmm0, xmm0
        BytePattern.tempInstance().findPattern("0F 5B C0 F3 0F 59 C1 41 0F 2E C0 7A 4D");
        if (BytePattern.tempInstance().hasSize(1, "分岐処理修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // movd    xmm0, [rsp+11158h+arg_8]
            eventDialogProc2ReturnAddress1 = address + 0x0F;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc2));
            writeln("JMP for eventDialog2Injector (v1_32_plus) created.");
        }
        else {
            e.unmatchdEventDialog2Injector = true;
        }
        break;
    default:
        e.versionEventDialog2Injector = true;
    }

    return e;
}

DllError eventDialog3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // inc     edi
        BytePattern.tempInstance().findPattern("FF C7 3B 7B 10 8B 94 24 90 03 00 00 4C 8D");
        if (BytePattern.tempInstance().hasSize(1, "カウントアップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            //  mov     r11, 0BFFFFFF43FFFFFFh
            eventDialogProc3ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc3));
            writeln("JMP for eventDialog3Injector created.");
        }
        else {
            e.unmatchdEventDialog3Injector = true;
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
        // inc     edi
        BytePattern.tempInstance().findPattern("FF C7 3B 7B 10 8B 94 24 90 03 00 00 4C 8D");
        if (BytePattern.tempInstance().hasSize(1, "カウントアップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            //  mov     r11, 0BFFFFFF43FFFFFFh
            eventDialogProc3ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc3V130));
            writeln("JMP for eventDialog3Injector (v1_30_plus) created.");
        }
        else {
            e.unmatchdEventDialog3Injector = true;
        }
        break;
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // inc     edi
        BytePattern.tempInstance().findPattern("FF C7 3B 7B 10 44 8B 84 24 70 11 00 00");
        if (BytePattern.tempInstance().hasSize(1, "カウントアップ")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            //  mov     r11, 0BFFFFFF43FFFFFFh
            eventDialogProc3ReturnAddress = address + 0x14;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)eventDialogProc3V132));
            writeln("JMP for eventDialog3Injector (v1_32_plus) created.");
        }
        else {
            e.unmatchdEventDialog3Injector = true;
        }
        break;
    default:
        e.versionEventDialog3Injector = true;
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | eventDialog1Injector(options);
    result = result | eventDialog2Injector(options);
    result = result | eventDialog3Injector(options);

    return result;
}
