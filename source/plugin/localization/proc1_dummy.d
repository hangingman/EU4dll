module plugin.localization.proc1_dummy;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError localizationProc1Injector(RunOptions options){
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // mov     [rsp+arg_10], rbx
        BytePattern.tempInstance().findPattern("48 89 5C 24 18 55 41 56 41 57 48 83 EC 20 4D 8B F0");
        if (BytePattern.tempInstance().hasSize(1, "std::basic_string<char>#insertをフック")) {
            localizationProc1CallAddress1 = BytePattern.tempInstance().getFirst().address;
            writeln("Dummy Hook for localizationProc1Injector called.");
        }
        else {
            e.unmatchdLocalizationProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionLocalizationProc1Injector = true;
        break;
    }
    }

    return e;
}
