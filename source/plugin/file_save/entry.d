module plugin.file_save.entry;

import plugin.constant;
import plugin.input; // For DllError and RunOptions
import plugin.file_save.common; // 共通変数・構造体を使用するため

// 各Injectorモジュールの関数をインポート
import plugin.file_save.proc1;
import plugin.file_save.proc2;
import plugin.file_save.proc3;
import plugin.file_save.proc4;
import plugin.file_save.proc5;
import plugin.file_save.proc6;
import plugin.file_save.proc7;

DllError init(EU4Ver eu4Version)
{
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    /* UTF-8ファイルを列挙できない問題は解決された */
    result = result | fileSaveProc1Injector(options);
    result = result | fileSaveProc2Injector(options);
    result = result | fileSaveProc3Injector(options);
    // これは使われなくなった？
    //result |= fileSaveProc4Injector(options);
    result = result | fileSaveProc5Injector(options);
    result = result | fileSaveProc6Injector(options);
    result = result | fileSaveProc7Injector(options);

    return result;
}
