module plugin.map_popup;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート

extern(C) {
    void mapPopupProc1();
    void mapPopupProc2();
    void mapPopupProc2V130();
    void mapPopupProc3();
    void mapPopupProc3V130();
}

size_t mapPopupProc1ReturnAddress;
size_t mapPopupProc1CallAddress;
size_t mapPopupProc2ReturnAddress;
size_t mapPopupProc3ReturnAddress;

DllError mapPopupProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
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
        // movzx   r8d, byte ptr [rdi+rax]
        BytePattern.tempInstance().findPattern("44 0F B6 04 07 BA 01 00 00 00 48 8D 4D D0");
        if (BytePattern.tempInstance().hasSize(1, "ループ１の文字列コピー")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call {sub_xxxxx}
            // mapPopupProc1CallAddress = Injector::GetBranchDestination(address + 14).as_int();
            mapPopupProc1CallAddress = address + 14; // 仮のアドレス

            // Injector::MakeJMP(address, mapPopupProc1, true);
            writeln("Dummy JMP for mapPopupProc1Injector called.");

            // nop
            mapPopupProc1ReturnAddress = address + 19;
        }
        else {
            e.unmatchdMapPopupProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionMapPopupProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError mapPopupProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0: {
        //  movzx   eax, byte ptr [rax+rdi]
        BytePattern.tempInstance().findPattern("0F B6 04 38 4D 8B B4 C7 00 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ループ１の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // Injector::MakeJMP(address, mapPopupProc2, true);
            writeln("Dummy JMP for mapPopupProc2Injector (v1_29_X) called.");

            // jz xxxxx
            mapPopupProc2ReturnAddress = address + 15;
        }
        else {
            e.unmatchdMapPopupProc2Injector = true;
        }
        break;
    }
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
        //  movzx   eax, byte ptr [rax+rdi]
        BytePattern.tempInstance().findPattern("0F B6 04 38 4D 8B B4 C7 20 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ループ１の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // Injector::MakeJMP(address, mapPopupProc2V130, true);
            writeln("Dummy JMP for mapPopupProc2Injector (v1_30_X_plus) called.");

            // jz xxxxx
            mapPopupProc2ReturnAddress = address + 15;
        }
        else {
            e.unmatchdMapPopupProc2Injector = true;
        }
        break;
    }
    default: {
        e.versionMapPopupProc2Injector = true;
        break;
    }
    }

    return e;
}

DllError mapPopupProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0: {
        //  movzx   eax, byte ptr [rbx+rax]
        BytePattern.tempInstance().findPattern("0F B6 04 03 4D 8B 9C C7 00 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ループ２の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // Injector::MakeJMP(address, mapPopupProc3, true);
            writeln("Dummy JMP for mapPopupProc3Injector (v1_29_X) called.");

            //  movss   dword ptr [rbp+88h], xmm3
            mapPopupProc3ReturnAddress = address + 0x13;
        }
        else {
            e.unmatchdMapPopupProc3Injector = true;
        }
        break;
    }
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
        //  movzx   eax, byte ptr [rbx+rax]
        BytePattern.tempInstance().findPattern("0F B6 04 03 4D 8B 9C C7 20 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ループ２の文字取得")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // Injector::MakeJMP(address, mapPopupProc3V130, true);
            writeln("Dummy JMP for mapPopupProc3Injector (v1_30_X_plus) called.");

            //  movss   dword ptr [rbp+88h], xmm3
            mapPopupProc3ReturnAddress = address + 0x13;
        }
        else {
            e.unmatchdMapPopupProc3Injector = true;
        }
        break;
    }
    default: {
        e.versionMapPopupProc3Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | mapPopupProc1Injector(options);
    result = result | mapPopupProc2Injector(options);
    result = result | mapPopupProc3Injector(options);

    return result;
}
