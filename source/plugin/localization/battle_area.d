module plugin.localization.battle_area;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import std.stdio; // writeln を使用するため

DllError localizationProc2Injector(RunOptions options) {
    DllError e;

    // if (!options.reversingWordsBattleOfArea) return e; // FIXME: RunOptionsにreversingWordsBattleOfAreaがないためコメントアウト

    switch (options.eu4Version) {
    case EU4Ver.v1_29_4_0: {
        // nop
        BytePattern.tempInstance().findPattern("90 49 83 C9 FF 45 33 C0 48 8B D0 48 8B CB E8 13 70 EB FF");
        if (BytePattern.tempInstance().hasSize(1, "Battle of areaを逆転させる")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // nop
            localizationProc2ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc2));
            writeln("JMP for localizationProc2Injector (v1_29_4_0) created.");
        }
        else {
            e.unmatchdLocalizationProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0: {
        // mov     rcx, [rdi+30h]
        BytePattern.tempInstance().findPattern("48 8B 4F 30 48 83 C1 10 48 8B 01");
        if (BytePattern.tempInstance().hasSize(2, "Battle of areaを逆転させる")) {
            // nop
            size_t address = BytePattern.tempInstance().getFirst().address(0x3B);

            // nop
            localizationProc2ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc2));
            writeln("JMP for localizationProc2Injector (v1_30_X) created.");
        }
        else {
            e.unmatchdLocalizationProc2Injector = true;
        }
        break;
    }
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // mov     rax, [rdi+30h]
        BytePattern.tempInstance().findPattern("48 8B 47 30 4C 8B 40 28 49 83 C0 10");
        if (BytePattern.tempInstance().hasSize(1, "Battle of areaを逆転させる")) {
            // nop
            size_t address = BytePattern.tempInstance().getFirst().address(0x1D);

            // nop
            localizationProc2ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)localizationProc2));
            writeln("JMP for localizationProc2Injector (v1_31_X) created.");
        }
        else {
            e.unmatchdLocalizationProc2Injector = true;
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("Battle of areaを逆転させる [NG]");
        e.versionLocalizationProc2Injector = true;
        break;
    }
    }

    return e;
}
