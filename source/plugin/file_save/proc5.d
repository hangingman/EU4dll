module plugin.file_save.proc5;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc5Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     r8, [r14+598h]
        BytePattern.tempInstance()
            .findPattern("4D 8D 86 98 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 50");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc5));
            writeln("JMP for fileSaveProc5Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
        // lea     r8, [r14+5C0h]
        BytePattern.tempInstance()
            .findPattern("4D 8D 86 C0 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 50");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc5V130));
            writeln("JMP for fileSaveProc5Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        // lea     r8, [r14+5C0h]
        BytePattern.tempInstance()
            .findPattern("4D 8D 86 C0 05 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 60");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのツールチップを表示できるようにする2"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc5CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea rdx, {aZy}
            // fileSaveProc5MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc5MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc5ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc5V1316));
            writeln("JMP for fileSaveProc5Injector (v1_31_6_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc5Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc5Injector = true;
    }

    return e;
}
