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
