module plugin.file_save.proc3;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc3Injector(RunOptions options)
{
    DllError e;
    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_2_0:
    case EU4Ver.v1_29_4_0:
        //  jmp     short loc_xxxxx
        BytePattern.tempInstance().findPattern("EB 6E 48 8D 15 ? ? ? ? FF 90 98 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする"))
        {
            //  lea     rdx, aSave_game_titl ; "save_game_title"
            size_t address = BytePattern.tempInstance().getFirst().address + 0x2;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call sub_xxxxx
            fileSaveProc3ReturnAddress = address + 0x1A;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc3));
            writeln("JMP for fileSaveProc3Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc3Injector = true;
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
        //  jmp     short loc_xxxxx
        BytePattern.tempInstance()
            .findPattern("EB 6E 48 8D 15 ? ? ? ? FF 90 98 00 00 00 48");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする"))
        {
            //  lea     rdx, aSave_game_titl ; "save_game_title"
            size_t address = BytePattern.tempInstance().getFirst().address + 0x2;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call sub_xxxxx
            fileSaveProc3ReturnAddress = address + 0x1A;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc3V130));
            writeln("JMP for fileSaveProc3Injector (v1_30_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        BytePattern.tempInstance().findPattern("45 33 C0 48 8D 93 80 05 00 00 49 8B CE");
        if (BytePattern.tempInstance().hasSize(1, "ダイアログでのセーブエントリのタイトルを表示できるようにする"))
        {
            //  xor     r8d, r8d
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc3CallAddress = cast(size_t)&utf8ToEscapedStr;

            // call {xxxxx}
            // fileSaveProc3CallAddress2 = Injector::GetBranchDestination(address + 0xD).as_int();
            fileSaveProc3CallAddress2 = address + 0x0D + get_branch_destination_offset(
                cast(void*)(address + 0x0D), 4); // Placeholder

            // test rsi,rsi
            fileSaveProc3ReturnAddress = address + 0x12;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc3V1316));
            writeln("JMP for fileSaveProc3Injector (v1_31_6_plus) created.");
        }
        else
        {
            e.unmatchdFileSaveProc3Injector = true;
        }
        break;
    default:
        e.versionFileSaveProc3Injector = true;
    }

    return e;
}
