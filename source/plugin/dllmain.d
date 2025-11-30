module plugin.dllmain;

import std.stdio;
import core.stdc.stdlib;
import plugin.byte_pattern;
import plugin.constant; // RunOptionsを使うので必要
import plugin.misc;
import plugin.input : DllError; // DllErrorをインポート
import plugin.mod; // 翻訳MOD読み込みのために追加

// import freck.streams.filestream; // freck-streams を削除

import Font = plugin.font;
import TextView = plugin.main_text;
import MapAdj = plugin.map_adjustment;
import MapJustify = plugin.map_justify;
import MapView = plugin.map_view;
import Input = plugin.input.entry; // 修正
import IME = plugin.ime;
import PopupCharOnMap = plugin.map_popup;
import DateFormat = plugin.date;
import ListFieldAdj = plugin.list_field_adjustment;
import NameOrder = plugin.localization.entry; // 修正
import ButtonAndToolTip = plugin.tooltip_and_button;
import EventDialog = plugin.event_dialog;
import FileSave = plugin.file_save.entry; // 修正
import Options = plugin.options;
import PluginVersion = plugin.plugin_version;

extern (C):

pragma(crt_constructor)
void hijack()
{
    // unittestのときは処理を何もしない
    version (unittest)
    {
        // NOP
    }
    else
    {
        hijackProcess();
    }
}

void hijackProcess()
{
    BytePattern.startLog("eu4jps");

    DllError success;

    // versionを文字列から取得
    EU4Ver eu4Version = Misc.getVersion(); // 今回のテストでコメントアウトを解除

    // 翻訳MODの読み込み
    loadTranslationMods();

    // TODO: フォント関連の修正
    // success = success | Font.init(eu4Version);

    // TODO: 本文テキスト表示の修正
    // success = success | TextView.init(eu4Version);

    // TODO: マップ文字位置調整
    // success = success | MapAdj.init(eu4Version);

    // TODO: マップ文字justify
    // success = success | MapJustify.init(eu4Version);

    // TODO: マップ文字表示
    // success = success | MapView.init(eu4Version);

    // TODO: その他
    // success |= Misc.init(eu4Version); // Misc.init is not defined in misc.d

    // TODO: 入力修正
    // success = success | Input.init(eu4Version);

    // TODO: IME修正
    // success = success | IME.init(eu4Version);

    // TODO: ツールチップとボタン
    // success = success | ButtonAndToolTip.init(eu4Version);

    // TODO: ツールチップ追加処理
    // success |= ToolTipApx.init(eu4Version);

    // TODO: マップ上のポップアップ文字
    // success = success | PopupCharOnMap.init(eu4Version);

    // TODO: issue-19の修正
    // success |= InputIssue19.init(eu4Version);

    // TODO: イベントダイアログの修正とマップ上の修正
    // success = success | EventDialog.init(eu4Version);

    // TODO: ファイルセーブ関連
    // success = success | FileSave.init(eu4Version);

    // TODO: オプションの読み込み
    // TODO: options.d内のDLLエラーフラグは未実装のためコメントアウト
    // success = success | Options.init(eu4Version);

    // TODO: DateFormat(issue-66)の修正
    // success = success | DateFormat.init(eu4Version);

    // TODO: Listの文字調整（issue-99）
    // success = success | ListFieldAdj.init(eu4Version);

    // TODO: 名前の順序(issue-98)
    // success = success | NameOrder.init(eu4Version);

    // TODO: プラグインバージョン情報の初期化
    bool pluginVersionInitResult = PluginVersion.init(eu4Version);
    if (!pluginVersionInitResult) {
        // PluginVersion.initが失敗した場合、DllErrorにエラーフラグを設定する（ここでは仮に何もしない）
        // success.versionPluginVersionProc1Injector = true; // DllErrorの構造変更が必要になるため、一時的にコメントアウト
        BytePattern.tempInstance().debugOutput("PluginVersion.init failed.");
    }


    if (pluginVersionInitResult) // PluginVersion.initの結果を直接判定
    {
        BytePattern.tempInstance().debugOutput("DLL [OK]");
    }
    else
    {
        BytePattern.tempInstance().debugOutput("DLL [NG] (PluginVersion.init failed)");
        exit(-1);
    }
    BytePattern.tempInstance().flushLog(); // ログバッファを強制的にフラッシュ
}
