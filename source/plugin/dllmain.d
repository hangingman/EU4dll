module plugin.dllmain;

import std.logger; // std.logger全体をインポート
import std.stdio;
import core.stdc.stdlib;
import core.sys.posix.unistd : write;
import std.process;
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
import ReloadTrace = plugin.localization.reload_trace;
import SetTextHook = plugin.localization.settext_hook;
import ButtonAndToolTip = plugin.tooltip_and_button;
import EventDialog = plugin.event_dialog;
import FileSave = plugin.file_save.entry; // 修正
import Options = plugin.options;
import PluginVersion = plugin.plugin_version;

// Decode opt-in (item 15): Font.init / TextView.init run only when the
// environment variable EU4DLL_ENABLE_DECODE is exactly "1". The decision
// is a pure helper so it can be unit tested without starting EU4.
bool decodeOptInEnabled(string value)
{
    return value == "1";
}

// True when any injector flag in a DllError is set.
bool dllErrorHasAny(DllError error)
{
    foreach (field; error.tupleof)
    {
        if (field)
            return true;
    }
    return false;
}

unittest
{
    assert(decodeOptInEnabled("1"));
    assert(!decodeOptInEnabled(null));
    assert(!decodeOptInEnabled(""));
    assert(!decodeOptInEnabled("0"));
    assert(!decodeOptInEnabled("true"));

    DllError clean;
    assert(!dllErrorHasAny(clean));
    DllError failed;
    failed.versionMainTextProc1Injector = true;
    assert(dllErrorHasAny(failed));
}

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
        enum msg = "[DIAGNOSTIC-RAW] crt_constructor entered\n";
        write(2, msg.ptr, msg.length);
        hijackProcess();
    }
}

void hijackProcess()
{
    enum msg = "[DIAGNOSTIC-RAW] hijackProcess entered\n";
    write(2, msg.ptr, msg.length);

    // std.logger の設定
    // ログファイルへの出力設定
    // sharedLog に FileLogger を設定
    std.logger.sharedLog = new shared FileLogger("pattern_eu4jps.log", LogLevel.trace);

    DllError success;

    // versionを文字列から取得
    EU4Ver eu4Version = Misc.getVersion(); // 今回のテストでコメントアウトを解除

    // 翻訳MODの読み込み
    auto skipTranslations = environment.get("EU4DLL_SKIP_TRANSLATIONS");
    if (skipTranslations == "1")
    {
        std.logger.info("[DIAGNOSTIC] EU4DLL_SKIP_TRANSLATIONS=1; skipping loadTranslationMods()");
    }
    else
    {
        loadTranslationMods();
    }

    ReloadTrace.initReloadTrace(eu4Version);
    SetTextHook.initSetTextHook(eu4Version);

    // Decode enablement (item 15, opt-in only): run the font and main
    // text initialisers only when EU4DLL_ENABLE_DECODE=1 is set
    // explicitly. Upstream order is Font before TextView. Failures are
    // aggregated into `success` and logged, but are NOT fatal here:
    // on Linux v1.37.5 most injectors in font.d / main_text.d have no
    // matching case yet (items 12/13 derived AOB patterns only; the
    // Linux fetch-site hooks themselves are not written), so they
    // return version/unmatched errors and apply no patch. Making that
    // exit(-1) would break startup for an opt-in diagnostic, and the
    // PluginVersion gate below remains the fatal one. When the
    // variable is unset, behaviour is exactly as before this item.
    if (decodeOptInEnabled(environment.get("EU4DLL_ENABLE_DECODE")))
    {
        std.logger.info("[DIAGNOSTIC] EU4DLL_ENABLE_DECODE=1; calling Font.init and TextView.init (opt-in)");
        DllError decodeResult;
        decodeResult = decodeResult | Font.init(eu4Version);
        decodeResult = decodeResult | TextView.init(eu4Version);
        success = success | decodeResult;
        if (dllErrorHasAny(decodeResult))
        {
            std.logger.error("[DIAGNOSTIC] Decode init reported injector errors; "
                ~ "no decode patch is active for the failed injectors "
                ~ "(see memory-bank/details/decode_optin_enablement.md). Continuing startup.");
        }
        else
        {
            std.logger.info("[DIAGNOSTIC] Decode init [OK]");
        }
    }
    else
    {
        std.logger.info("[DIAGNOSTIC] EU4DLL_ENABLE_DECODE is not 1; skipping Font.init / TextView.init");
    }

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
    if (!pluginVersionInitResult)
    {
        // PluginVersion.initが失敗した場合、DllErrorにエラーフラグを設定する（ここでは仮に何もしない）
        // success.versionPluginVersionProc1Injector = true; // DllErrorの構造変更が必要になるため、一時的にコメントアウト
        std.logger.error("PluginVersion.init failed.");
    }

    if (pluginVersionInitResult) // PluginVersion.initの結果を直接判定
    {
        std.logger.info("DLL [OK]");
    }
    else
    {
        std.logger.error("DLL [NG] (PluginVersion.init failed)");
        exit(-1);
    }
}
