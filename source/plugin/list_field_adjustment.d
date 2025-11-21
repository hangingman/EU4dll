module plugin.list_field_adjustment;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions

extern(C) {
    void listFieldAdjustmentProc1();
    void listFieldAdjustmentProc2();
    void listFieldAdjustmentProc3();
    void listFieldAdjustmentProc1_v131();
    void listFieldAdjustmentProc1_v1315();
    void listFieldAdjustmentProc2_v131();
    void listFieldAdjustmentProc2_v1315();
    void listFieldAdjustmentProc3_v1315();
}

// Return addresses
// NOTE: These should ideally be extern(C) __gshared if accessed from ASM, 
// but following the pattern in map_adjustment.d for now.
size_t listFieldAdjustmentProc1ReturnAddress;
size_t listFieldAdjustmentProc2ReturnAddress;
size_t listFieldAdjustmentProc3ReturnAddress;
size_t listFieldAdjustmentProc2V1315ReturnAddress;

DllError listFieldAdjustmentProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
        // mov     rcx, [rbp+0D0h+var_130]
        BytePattern.tempInstance().findPattern("48 8B 4D A0 F3 0F 10 B1 48 08 00 00 42 0F B6 04 20");
        if (BytePattern.tempInstance().hasSize(1, "フォント読み出し")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz loc_xxxxx
            listFieldAdjustmentProc1ReturnAddress = address + 0x18;

            // Injector::MakeJMP(address, listFieldAdjustmentProc1_v1315, true);
            writeln("Dummy JMP for listFieldAdjustmentProc1Injector (v1_31_5+) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc1Injector = true;
        }
        break;
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
        // mov     rcx, [rbp+0C0h+var_128]
        BytePattern.tempInstance().findPattern("48 8B 4D 98 F3 0F 10 B1 48 08 00 00 41 0F B6 04 04");
        if (BytePattern.tempInstance().hasSize(1, "フォント読み出し")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz loc_xxxxx
            listFieldAdjustmentProc1ReturnAddress = address + 0x18;

            // Injector::MakeJMP(address, listFieldAdjustmentProc1_v131, true);
            writeln("Dummy JMP for listFieldAdjustmentProc1Injector (v1_31_1-4) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc1Injector = true;
        }
        break;
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
        // mov     r8, [rbp+0B0h+var_118]
        BytePattern.tempInstance().findPattern("4C 8B 45 98 F3 41 0F 10 B0 48 08 00 00");
        if (BytePattern.tempInstance().hasSize(1, "フォント読み出し")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jz loc_xxxxx
            listFieldAdjustmentProc1ReturnAddress = address + 0x19;

            // Injector::MakeJMP(address, listFieldAdjustmentProc1, true);
            writeln("Dummy JMP for listFieldAdjustmentProc1Injector (v1_29/30) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc1Injector = true;
        }
        break;
    default:
        e.versionListFieldAdjustmentProc1Injector = true;
    }

    return e;
}

DllError listFieldAdjustmentProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
        // inc     ebx
        BytePattern.tempInstance().findPattern("FF C3 4C 8B 4F 10 41 3B D9 0F 8D 20 02 00 00");
        if (BytePattern.tempInstance().hasSize(1, "カウントを進める")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jge     loc_{xxxxx}
            // listFieldAdjustmentProc2V1315ReturnAddress = Injector::GetBranchDestination(address + 0x09).as_int();
            // FIXME: Implement GetBranchDestination logic
            listFieldAdjustmentProc2V1315ReturnAddress = address + 0x09 + 5; // Placeholder: instruction size 5? Need to check relative offset.
            // The C++ code uses Injector::GetBranchDestination(address + 0x09).
            // 0F 8D 20 02 00 00 is JGE rel32. 
            // address+9 is where the JGE instruction starts.
            // We need to read the offset and add it.
            // For now, just a placeholder or dummy value as we are not executing.
            
            // 
            listFieldAdjustmentProc2ReturnAddress = address + 0x0F;

            // Injector::MakeJMP(address, listFieldAdjustmentProc2_v1315, true);
            writeln("Dummy JMP for listFieldAdjustmentProc2Injector (v1_31_5+) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc2Injector = true;
        }
        break;
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
        // inc     ebx
        BytePattern.tempInstance().findPattern("FF C3 4C 8B 57 10 0F B6 95 08 01 00 00 41 3B DA");
        if (BytePattern.tempInstance().hasSize(1, "カウントを進める")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jge     loc_xxxxx
            listFieldAdjustmentProc2ReturnAddress = address + 0x10;

            // Injector::MakeJMP(address, listFieldAdjustmentProc2_v131, true);
            writeln("Dummy JMP for listFieldAdjustmentProc2Injector (v1_31_1-4) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc2Injector = true;
        }
        break;
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
        // inc     ebx
        BytePattern.tempInstance().findPattern("FF C3 4C 8B 4F 10 0F B6 95 F8 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "カウントを進める")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // jge     loc_xxxxx
            listFieldAdjustmentProc2ReturnAddress = address + 0x10;

            // Injector::MakeJMP(address, listFieldAdjustmentProc2, true);
            writeln("Dummy JMP for listFieldAdjustmentProc2Injector (v1_29/30) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc2Injector = true;
        }
        break;
    default:
        e.versionListFieldAdjustmentProc2Injector = true;
    }

    return e;
}

DllError listFieldAdjustmentProc3Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
        // mov     rcx, [rax+rcx*8]
        BytePattern.tempInstance().findPattern("48 8B 0C C8 44 8B 0C 91 45 33 C0 48 8D 54 24 28");
        if (BytePattern.tempInstance().hasSize(2, "文字列切り取り処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call sub_xxxxx
            listFieldAdjustmentProc3ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, listFieldAdjustmentProc3_v1315, true);
            writeln("Dummy JMP for listFieldAdjustmentProc3Injector (v1_31_5+) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc3Injector = true;
        }
        break;
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
        // mov     rcx, [rax+rcx*8]
        BytePattern.tempInstance().findPattern("48 8B 0C C8 44 8B 0C 91 45 33 C0 48 8D 54 24 20");
        if (BytePattern.tempInstance().hasSize(2, "文字列切り取り処理")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // call sub_xxxxx
            listFieldAdjustmentProc3ReturnAddress = address + 0x13;

            // Injector::MakeJMP(address, listFieldAdjustmentProc3, true);
            writeln("Dummy JMP for listFieldAdjustmentProc3Injector (v1_29-31_4) called.");
        }
        else {
            e.unmatchdListFieldAdjustmentProc3Injector = true;
        }
        break;
    default:
        e.versionListFieldAdjustmentProc3Injector = true;
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | listFieldAdjustmentProc1Injector(options);
    result = result | listFieldAdjustmentProc2Injector(options);
    result = result | listFieldAdjustmentProc3Injector(options);

    return result;
}
