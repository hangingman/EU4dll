module plugin.file_save.proc4;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc4Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
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
    case EU4Ver.v1_33_3_0:
        // lea     r8, [rbp+0]
        BytePattern.tempInstance()
            .findPattern("4C 8D 45 00 48 8D 15 ? ? ? ? 48 8D 4C 24 70 E8 ? ? ? ? 90");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする1"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc4CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc4MarkerAddress = Injector::GetBranchDestination(address + 4).as_int();
            fileSaveProc4MarkerAddress = address + 0x04 + get_branch_destination_offset(
                cast(void*)(address + 0x04), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc4ReturnAddress = address + 0x10;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc4));
            writeln("JMP for fileSaveProc4Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc4Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc4Injector = true;
    }

    return e;
}
