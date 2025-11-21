module plugin.tooltip_and_button.proc6;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.patcher.patcher : ScopedPatch, PatchManager; // ScopedPatch, PatchManagerを使用するためにインポート

DllError tooltipAndButtonProc6Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_31_5_0:
        // inc edx
        BytePattern.tempInstance().findPattern("A7 52 2D 20 00 00 00 00");
        if (BytePattern.tempInstance().hasSize(1, "空白をノーブレークスペースに変換")) {
            PatchManager.instance().addPatch(cast(void*)(BytePattern.tempInstance().getFirst().address + 3), cast(ubyte[])[0xA0]);
            writeln("WriteMemory for tooltipAndButtonProc6Injector called.");
        }
        else {
            e.unmatchdTooltipAndButtonProc6Injector = true;
        }
        break;
    default:
        e.versionTooltipAndButtonProc6Injector = true;
    }

    return e;
}
