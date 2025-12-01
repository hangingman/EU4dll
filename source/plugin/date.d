module plugin.date;

import std.stdio;
import std.logger; // std.loggerのために追加
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

extern(C) {
    void* dateProc2() { return null; }
}

size_t dateProc2ReturnAddress;

// DateFormatに相当する構造体
struct DateFormat {
    char[11] text;
}

DllError dateProc1Injector(RunOptions options) {
    DllError e;

    // ex) 1444年11月11日
    DateFormat isoFormat;
    isoFormat.text = ['y',' ',0x0F,' ','m','w',' ','d',' ',0x0E,0];

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
        // d w mw w y
        BytePattern.tempInstance().findPattern("64 20 77 20 6D");
        if (BytePattern.tempInstance().hasSize(1, "右上の表記を変更")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            PatchManager.instance().addPatch(cast(void*)address, cast(ubyte[])isoFormat.text);
            std.logger.info("WriteMemory for dateProc1Injector called.");
        }
        else {
            e.unmatchdDateProc1Injector = true;
        }
        break;
    }
    default: {
        e.versionDateProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | dateProc1Injector(options);

    return result;
}
