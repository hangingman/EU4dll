module plugin.input;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;
// FIXME: escape_tool.d を後で作成し、インポートする

// DllErrorに相当する構造体
// 実際のDllErrorはdllmain.dの周辺で定義されているはずだが、
// 現状は最小限の定義とする
struct DllError {
    bool unmatchdInputProc1Injector;
    bool versionInputProc1Injector;
    bool unmatchdInputProc2Injector;
    bool versionInputProc2Injector;

    // ビットOR演算子をオーバーロードして、複数のエラーを結合できるようにする
    DllError opBinary(string op : "|")(DllError rhs) const {
        DllError result;
        result.unmatchdInputProc1Injector = this.unmatchdInputProc1Injector || rhs.unmatchdInputProc1Injector;
        result.versionInputProc1Injector = this.versionInputProc1Injector || rhs.versionInputProc1Injector;
        result.unmatchdInputProc2Injector = this.unmatchdInputProc2Injector || rhs.unmatchdInputProc2Injector;
        result.versionInputProc2Injector = this.versionInputProc2Injector || rhs.versionInputProc2Injector;
        return result;
    }
}

// RunOptionsに相当する構造体（仮）
// 実際のRunOptionsはdllmain.dの周辺で定義されているはずだが、
// 現状はeu4Versionフィールドのみを持つ最小限の定義とする
struct RunOptions {
    EU4Ver eu4Version; // 'version' を 'eu4Version' に変更
}


// FIXME: inputProc1, inputProc1V130, inputProc2 のD言語版関数をasmファイルから移植する
// 現状はダミーの関数定義のみ
extern(C) {
    void inputProc1() {}
    void inputProc1V130() {}
    void inputProc2() {}

    // FIXME: utf8ToEscapedStr3 のD言語版関数をescape_tool.dに定義し、ここで呼び出す
    // 現状はダミーの関数定義のみ
    size_t utf8ToEscapedStr3(size_t arg) {
        writeln("Dummy utf8ToEscapedStr3 called.");
        return arg;
    }
}

size_t inputProc1ReturnAddress1;
size_t inputProc1ReturnAddress2;
size_t inputProc1CallAddress;
size_t inputProc2ReturnAddress;

// Inputモジュール内で関数を定義
DllError inputProc1Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) { // 'options.version' を 'options.eu4Version' に変更
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0: {
        // mov     eax, dword ptr    [rbp+120h+var_198+0Ch]
        BytePattern.tempInstance().findPattern("8B 45 94 32 DB 3C 80 73 05 0F B6 D8 EB 10");
        if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する１")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            inputProc1CallAddress = cast(size_t)utf8ToEscapedStr3;

            // mov     rax, [r13+0]
            inputProc1ReturnAddress1 = address + 0x1E;

            // FIXME: Injector::MakeJMP に相当するD言語でのフック処理を実装する
            // Injector.MakeJMP(address, cast(size_t)inputProc1, true);
            writeln("Dummy JMP for inputProc1Injector (1) called.");
        }
        else {
            e.unmatchdInputProc1Injector = true;
        }

        // call    qword ptr [rax+18h]
        BytePattern.tempInstance().findPattern("FF 50 18 E9 ? ? 00 00 49 8B 45 00");
        if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する２")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            // jmp     loc_{xxxxx}
            // FIXME: Injector::GetBranchDestination に相当するD言語でのアドレス取得処理を実装する
            // inputProc1ReturnAddress2 = Injector.GetBranchDestination(address + 0x3).as_int();
            writeln("Dummy GetBranchDestination for inputProc1Injector (2) called.");
            inputProc1ReturnAddress2 = address + 0x07; // 仮のアドレス
        }
        else {
            e.unmatchdInputProc1Injector = true;
        }

        break;
    }
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0: {
        // mov     eax, dword ptr    [rbp+120h+var_18C]
        BytePattern.tempInstance().findPattern("8B 45 94 32 DB 3C 80 73 05 0F B6 D8 EB 10");
        if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する１")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            inputProc1CallAddress = cast(size_t)utf8ToEscapedStr3;

            // mov     rax, [r13+0]
            inputProc1ReturnAddress1 = address + 0x1E;

            // FIXME: Injector::MakeJMP に相当するD言語でのフック処理を実装する
            // Injector.MakeJMP(address, cast(size_t)inputProc1V130, true);
            writeln("Dummy JMP for inputProc1Injector (2) called.");
        }
        else {
            e.unmatchdInputProc1Injector = true;
        }

        // call    qword ptr [rax+18h]
        BytePattern.tempInstance().findPattern("FF 50 18 E9 ? ? 00 00 49 8B 45 00");
        if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する２")) {
            size_t address = BytePattern.tempInstance().getFirst().address;
            // jmp     loc_{xxxxx}
            // inputProc1ReturnAddress2 = Injector.GetBranchDestination(address + 0x3).as_int();
            writeln("Dummy GetBranchDestination for inputProc1Injector (2) called.");
            inputProc1ReturnAddress2 = address + 0x07; // 仮のアドレス
        }
        else {
            e.unmatchdInputProc1Injector = true;
        }

        break;
    }
    default: {
        e.versionInputProc1Injector = true;
        break;
    }
    }

    return e;
}

DllError inputProc2Injector(RunOptions options) {
    DllError e;

    switch (options.eu4Version) { // 'options.version' を 'options.eu4Version' に変更
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
        // mov     rax, [rdi]
        BytePattern.tempInstance().findPattern("48 8B 07 48 8B CF 85 DB 74 08 FF 90 40 01 00 00");
        if (BytePattern.tempInstance().hasSize(1, "バックスペース処理の修正")) {
            size_t address = BytePattern.tempInstance().getFirst().address;

            // movzx   r8d, word ptr [rdi+56h]
            inputProc2ReturnAddress = address + 0x18;

            // FIXME: Injector::MakeJMP に相当するD言語でのフック処理を実装する
            // Injector.MakeJMP(address, cast(size_t)inputProc2, true);
            writeln("Dummy JMP for inputProc2Injector called.");
        }
        else {
            e.unmatchdInputProc2Injector = true;
        }
        break;
    }
    default: {
        e.versionInputProc2Injector = true;
        break;
    }
    }

    return e;
}

DllError init(EU4Ver eu4Version) { // 'version' を 'eu4Version' に変更
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version; // 'options.version' を 'options.eu4Version' に変更

    result = result | inputProc1Injector(options);
    result = result | inputProc2Injector(options);

    return result;
}
