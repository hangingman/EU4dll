module plugin.file_save.proc1;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.misc; // get_branch_destination_offset を使用するためにインポート
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc1Injector(RunOptions options)
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
        // mov     eax, [rcx+10h]
        BytePattern.tempInstance()
            .findPattern("8B 41 10 85 C0 0F 84 31 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "ファイル名を安全にしている場所を短絡する"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // fileSaveProc1ReturnAddress = Injector::GetBranchDestination(address + 0x5).as_int();
            fileSaveProc1ReturnAddress = address + 0x05 + get_branch_destination_offset(
                cast(void*)(address + 0x05), 4); // Placeholder

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc1));
            writeln("JMP for fileSaveProc1Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc1Injector = true; // 修正: Proc2InjectorではなくProc1Injectorのエラーフラグを立てる
        }
        break;
    default:
        e.versionFileSaveProc1Injector = true;
    }

    return e;
}
