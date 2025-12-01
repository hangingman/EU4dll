module plugin.input.entry;

import plugin.constant;
import plugin.input.common; // 共通変数・構造体を使用するため
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import plugin.misc; // get_branch_destination_offset を使用するため
import plugin.input; // DllError を使用するため
import plugin.byte_pattern; // BytePattern を使用するため
import std.logger;

// 各Injectorモジュールの関数をインポート
import plugin.input.proc1;
import plugin.input.proc2;
import plugin.input.proc3;
import plugin.input.proc4;
import plugin.input.proc5;
import plugin.input.proc6;
import plugin.input.proc7;
import plugin.input.proc8;
import plugin.input.proc9;
import plugin.input.proc10;
import plugin.input.proc11;
import plugin.input.proc12;

DllError init(EU4Ver eu4Version)
{
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    // cursorはC++側で設定されているので、D言語側からは読み取りのみ
    // そのため、初期化は不要。参照渡ししているが、参照先はC++側
    auto range = get_executable_memory_range();
    if (range[0] != 0 && range[1] != 0)
    {
        BytePattern.tempInstance().setModule().setPattern("48 8D 05 ? ? ? ? 48 8D 4C 24 20").search();
        if (BytePattern.tempInstance().hasSize(1, "cursorAddress")) {
            cursorAddress = BytePattern.tempInstance().getFirst().address;
            cursor = *cast(Cursor*) (cursorAddress + 0x3);
            std.logger.info("cursorAddress found: %x", cursorAddress);
        } else {
            std.logger.error("cursorAddress not found.");
        }

        BytePattern.tempInstance().setModule().setPattern("48 8D 05 ? ? ? ? 48 8D 4C 24 20").search();
        if (BytePattern.tempInstance().hasSize(2, "imeAddress")) {
            imeAddress = BytePattern.tempInstance().get(1).address; // 2番目のアドレスを取得
            ime = *cast(Ime*) (imeAddress + 0x3);
            std.logger.info("imeAddress found: %x", imeAddress);
        } else {
            std.logger.error("imeAddress not found.");
        }
    }

    result = result | InputProc1Injector(options);
    result = result | InputProc2Injector(options);
    result = result | InputProc3Injector(options);
    result = result | InputProc4Injector(options);
    result = result | InputProc5Injector(options);
    result = result | InputProc6Injector(options);
    result = result | InputProc7Injector(options);
    result = result | InputProc8Injector(options);
    result = result | InputProc9Injector(options);
    result = result | InputProc10Injector(options);
    result = result | InputProc11Injector(options);
    result = result | InputProc12Injector(options);

    return result;
}
