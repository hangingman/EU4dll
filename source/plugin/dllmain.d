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

// Decode enablement: Font.init / TextView.init run by default. The
// environment variable EU4DLL_ENABLE_DECODE=0 opts out (item 15 wired
// this as opt-in with "=1"; the owner decided on 2026-11-21 to flip the
// default so translation mods work without setting the variable). The
// decision is a pure helper so it can be unit tested without starting
// EU4.
bool decodeEnabled(string value)
{
    return value != "0";
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
    assert(decodeEnabled("1"));
    assert(decodeEnabled(null));
    assert(decodeEnabled(""));
    assert(!decodeEnabled("0"));
    assert(decodeEnabled("true"));

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

    // Decode enablement: run the font and main text initialisers by
    // default; EU4DLL_ENABLE_DECODE=0 skips them. Upstream order is
    // Font before TextView. Failures are aggregated into `success` and
    // logged, but are NOT fatal here: an injector that has no matching
    // case for the running version returns a version/unmatched error
    // and applies no patch, and making that exit(-1) would break
    // startup on versions the decode hooks do not cover yet. The
    // PluginVersion gate below remains the fatal one.
    if (decodeEnabled(environment.get("EU4DLL_ENABLE_DECODE")))
    {
        std.logger.info("[DIAGNOSTIC] Decode enabled (default; EU4DLL_ENABLE_DECODE=0 opts out); calling Font.init and TextView.init");
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
        std.logger.info("[DIAGNOSTIC] EU4DLL_ENABLE_DECODE=0; skipping Font.init / TextView.init");
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
