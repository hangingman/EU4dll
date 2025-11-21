module plugin.file_save.proc2;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc2Injector(RunOptions options)
{
    DllError e;
    string pattern;
    int offset = 0;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_33_3_0:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_31_6_0:
        // mov     [rbp+57h+var_90], 0FFFFFFFFFFFFFFFEh
        pattern = "48 C7 45 C7 FE FF FF FF 48 89 9C 24 F0 00 00 00 48 8B F9 33 DB";
        offset = 0x54;
        break;
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_1_0:
        pattern = "48 8D 05 ? ? ? FF 48 3B D0 75 06 48 8D 41 30 EB 02 FF D2 48 83 78 18 10 72";
        break;
    case EU4Ver.v1_30_5_0:
        pattern = "48 8D 05 51 D1 B3 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_30_4_0:
        pattern = "48 8D 05 ? ? B4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
        pattern = "48 8D 05 B1 4B B4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_30_1_0:
        pattern = "48 8D 05 91 4E B4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_29_4_0:
        pattern = "48 8D 05 91 FB A4 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_29_3_0:
        pattern = "48 8D 05 11 92 A5 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    case EU4Ver.v1_29_2_0:
        // lea     rax, sub_xxxxx ここしか取れなかった...
        pattern = "48 8D 05 01 A9 A5 FF 48 3B D0 75 06 48 8D 41 30";
        break;
    default:
        e.versionFileSaveProc2Injector = true;
        return e;
    }

    BytePattern.tempInstance().findPattern(pattern);
    if (BytePattern.tempInstance().hasSize(1, "ファイル名をUTF-8に変換して保存できるようにする"))
    {
        size_t address = BytePattern.tempInstance().getFirst().address + offset;

        fileSaveProc2CallAddress = cast(size_t)&escapedStrToUtf8;

        // jnz     short loc_xxxxx
        fileSaveProc2ReturnAddress = address + 0x14 + 0x1B;

        PatchManager.instance().addPatch(cast(void*)(address + 0x14), makeJmp(
                cast(void*)(address + 0x14), cast(void*) fileSaveProc2));
        writeln("JMP for fileSaveProc2Injector created.");
    }
    else
    {
        e.unmatchdFileSaveProc2Injector = true;
    }

    return e;
}
