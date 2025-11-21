module plugin.file_save.proc7;

import plugin.byte_pattern;
import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.patcher.patcher : PatchManager, makeJmp; // PatchManager, makeJmpを使用するためにインポート
import plugin.file_save.common; // 共通変数・構造体を使用するため
import std.stdio; // writeln を使用するため

DllError fileSaveProc7Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    {
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        // lea     rcx, [rbx+0C8h]
        BytePattern.tempInstance()
            .findPattern("48 8D 8B C8 00 00 00 48 8B 01 48 8D 54 24 28");
        if (BytePattern.tempInstance().hasSize(1, "セーブダイアログでのインプットテキストエリア"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;

            fileSaveProc7CallAddress = cast(size_t)&utf8ToEscapedStr2;

            // call    qword ptr [rax+80h]
            fileSaveProc7ReturnAddress = address + 0xF;

            PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                    void*) fileSaveProc7));
            writeln("JMP for fileSaveProc77Injector created.");
        }
        else
        {
            e.unmatchdFileSaveProc7Injector = true;
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
        // lea     rcx, [rbx+0C8h]
        size_t address;

        // epic
        BytePattern.tempInstance().findPattern("48 8D 8B C8 00 00 00 48 8B 01 48 8D 54 24 28");
        if (BytePattern.tempInstance().hasSize(1, "セーブダイアログでのインプットテキストエリア"))
        {
            address = BytePattern.tempInstance().getFirst().address;
        }
        // steam
        else if (BytePattern.tempInstance().hasSize(2, "セーブダイアログでのインプットテキストエリア"))
        {
            address = BytePattern.tempInstance().getSecond().address;
        }
        else
        {
            e.unmatchdFileSaveProc7Injector = true;
            break;
        }

        fileSaveProc7CallAddress = cast(size_t)&utf8ToEscapedStr2;

        // call    qword ptr [rax+80h]
        fileSaveProc7ReturnAddress = address + 0xF;

        PatchManager.instance().addPatch(cast(void*) address, makeJmp(cast(void*) address, cast(
                void*) fileSaveProc7));
        writeln("JMP for fileSaveProc7Injector (v1_30_plus) created.");

        break;
    default:
        e.versionFileSaveProc7Injector = true;
    }

    return e;
}
