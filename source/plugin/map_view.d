module plugin.map_view;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

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
