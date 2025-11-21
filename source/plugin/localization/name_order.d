module plugin.localization.name_order;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import std.stdio; // writeln を使用するため

DllError localizationProc5Injector(RunOptions options) {
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0: {
        pattern = "48 8B 4F 68 48 8B 01 FF 50 08 84 C0 74 5F 48 8B 07";
        offset = 0x40;
        
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5V131));
            writeln("JMP for localizationProc5Injector (v1_33_X) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_5_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 73 81 76 FF"; // 1.31.5.2
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5V131));
            writeln("JMP for localizationProc5Injector (v1_31_5_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 33 C0 76 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5V131));
            writeln("JMP for localizationProc5Injector (v1_31_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_3_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 23 C1 76 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5V131));
            writeln("JMP for localizationProc5Injector (v1_31_3_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_31_2_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 83 BA 76 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address(offset);

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5V131));
            writeln("JMP for localizationProc5Injector (v1_31_2_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }

    case EU4Ver.v1_30_5_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 ? FF 90 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5));
            writeln("JMP for localizationProc5Injector (v1_30_5_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 ? 1D 91 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5));
            writeln("JMP for localizationProc5Injector (v1_30_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_3_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 C7 1D 91 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5));
            writeln("JMP for localizationProc5Injector (v1_30_3_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_2_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 B7 1D 91 FF";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5));
            writeln("JMP for localizationProc5Injector (v1_30_2_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_30_1_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 27 1D";
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5));
            writeln("JMP for localizationProc5Injector (v1_30_1_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    case EU4Ver.v1_29_4_0: {
        pattern = "49 83 C9 FF 45 33 C0 48 8B D0 48 8B CF E8 27 41";			
        BytePattern.tempInstance().findPattern(pattern);
        if (BytePattern.tempInstance().hasSize(1, "nameを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc5ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc5));
            writeln("JMP for localizationProc5Injector (v1_29_4_0) created.");
        }
        else {
            // e.unmatchdLocalizationProc5Injector = true; // 削除
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("nameを逆転させる [NG]");
        // e.versionLocalizationProc5Injector = true; // 削除
        break;
    }
    }

    return e;
}
