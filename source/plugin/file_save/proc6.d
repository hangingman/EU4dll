module plugin.file_save.proc6;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc6Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     r8, [rbp+380h]
        BytePattern.tempInstance()
            .findPattern("4C 8D 85 80 03 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 30");
        if (BytePattern.tempInstance().hasSize(1, "スタート画面でのコンティニューのツールチップ"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc6CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea r8, {aZy}
            // fileSaveProc6MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc6MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc6));
            writeln("JMP for fileSaveProc6Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc6Injector = true;
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
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        // lea     r8, [rbp+730h+var_3A0]
        BytePattern.tempInstance()
            .findPattern("4C 8D 85 90 03 00 00 48 8D 15 ? ? ? ? 48 8D 4C 24 30");
        if (BytePattern.tempInstance().hasSize(1, "スタート画面でのコンティニューのツールチップ"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc6CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // lea r8, {aZy}
            // fileSaveProc6MarkerAddress = Injector::GetBranchDestination(address + 7).as_int();
            fileSaveProc6MarkerAddress = address + 0x07 + get_branch_destination_offset(
                cast(void*)(address + 0x07), 4); // Placeholder

            // call sub_xxxxx
            fileSaveProc6ReturnAddress = address + 0x13;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc6V130));
            writeln("JMP for fileSaveProc6Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc6Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc6Injector = true;
    }

    return e;
}
