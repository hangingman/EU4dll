module plugin.localization.space_fix;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため
import plugin.patcher.patcher : ScopedPatch, PatchManager; // ScopedPatch, PatchManagerを使用するため
import std.stdio; // writeln を使用するため

DllError localizationProc9Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0: {
        BytePattern.tempInstance().findPattern("20 2D 20 00 4D 4F 4E 54 48 53 00 00");
        if (BytePattern.tempInstance().hasSize(1, "Replace space")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            PatchManager.instance().addPatch(cast(void*)address + 0, cast(ubyte[])[0x20]);
            PatchManager.instance().addPatch(cast(void*)address + 1, cast(ubyte[])[0x2D]);
            PatchManager.instance().addPatch(cast(void*)address + 2, cast(ubyte[])[0x20]);
            writeln("WriteMemory for localizationProc9Injector called.");
        }
        else {
            // e.unmatchdLocalizationProc9Injector = true; // 削除
        }
        break;
    }
    default: {
        BytePattern.tempInstance().debugOutput("Replace space [NG]");
        // e.versionLocalizationProc9Injector = true; // 削除
        break;
    }
    }

    return e;
}
