module plugin.font;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート

extern(C) {
    void fontBufferHeapZeroClear();
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

    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // cmp     edi, 0FFh
        // 81 FF FF 00 00 00
        BytePattern.tempInstance().findPattern("81 FF FF 00 00 00 0F 87 2C 01 00 00 83");
        if (BytePattern.tempInstance().hasSize(1, "Char Code Point Limiter")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            // FIXME: Injector::WriteMemory に相当するD言語でのメモリ書き換え処理を実装する
            // Injector.WriteMemory!ubyte(address + 3, 0xFF, true);
            writeln("Dummy WriteMemory for charCodePointLimiterPatchInjector called.");
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
            // FIXME: Injector::GetBranchDestination に相当するD言語でのアドレス取得処理を実装する
            // fontBufferHeapZeroClearHeapJmpAddress = Injector.GetBranchDestination(address + 0x0).as_int();
            fontBufferHeapZeroClearHeapJmpAddress = address + 0x01; // 仮のアドレス
            // call {{cs:HeapAlloc}}
            // fontBufferHeapZeroClearHeepAllocJmpAddress = Injector.GetBranchDestination(address + 0xC).as_int();
            fontBufferHeapZeroClearHeepAllocJmpAddress = address + 0x0D; // 仮のアドレス
            // jz short loc_xxxxx
            fontBufferHeapZeroClearReturnAddress = address + 0x15;

            // Injector::MakeJMP(address, cast(size_t)fontBufferHeapZeroClear, true);
            writeln("Dummy JMP for fontBufferHeapZeroClearInjector called.");
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
            // Injector::WriteMemory!ubyte(BytePattern.tempInstance().getFirst().address(0x3), 0x10, true);
            writeln("Dummy WriteMemory for fontBufferClear1Injector called.");
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
            // Injector::WriteMemory!ubyte(BytePattern.tempInstance().getFirst().address(0x3), 0x10, true);
            writeln("Dummy WriteMemory for fontBufferClear2Injector called.");
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
            // Injector::WriteMemory!ubyte(BytePattern.tempInstance().getFirst().address(0x3), 0x10, true);
            writeln("Dummy WriteMemory for fontBufferExpansionInjector called.");
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
            // Injector::WriteMemory!ubyte(BytePattern.tempInstance().getFirst().address(0x6), 0x04, true);
            writeln("Dummy WriteMemory for fontSizeLimitInjector called.");
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

    return result;
}
