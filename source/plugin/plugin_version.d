module plugin.plugin_version;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import std.format; // format関数を使うために追加
import std.conv; // std.conv.to!stringを使うために追加
import std.string; // toStringzのために追加
import plugin.input : RunOptions; // RunOptionsのみを使用
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート
import plugin.mod; // translationMap を使用するためにインポート

extern (C)
{
    // プラグインのバージョン文字列を返す関数
    // GetPluginVersionの戻り値の型をvoid*からconst(char)*に変更し、C言語スタイルの文字列ポインタを返す
    const(char)* GetPluginVersion()
    {
        // 例として、ゲームのバージョンとプラグイン識別子を含む文字列を返す
        // この文字列は静的なものである必要があるため、toStringzで変換した結果を直接返す
        // 必要に応じて、RunOptionsから取得した実際のゲームバージョンを使用することもできるが、
        // GetPluginVersionは引数を受け取らないため、ここでは固定文字列とする
        static immutable string pluginVersionString = "EU4 v1.37.5.0 (EU4JPS)";
        return pluginVersionString.toStringz;
    }
}

bool detectEu4Version(RunOptions options)
{ // 戻り値をDllErrorからboolに変更 (役割に合わせて関数名を変更)

    BytePattern.tempInstance().debugOutput(format("PluginVersion.init: EU4 Version detected: %s", std.conv.to!string(
            options.eu4Version)));

    switch (options.eu4Version)
    {
        // 既存のバージョンケースをここに追加
    case EU4Ver.v1_29_1_0:
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
    case EU4Ver.v1_37_5: // v1.37.5を追加
        // EU4のバージョン文字列を検索するパターン
        BytePattern.tempInstance().findPattern("45 55 34 20 76 31 2E ? ? 2E ?");
        if (BytePattern.tempInstance().hasSize(1, "EU4 Version String Pattern"))
        {
            size_t address = BytePattern.tempInstance().getFirst().address;
            BytePattern.tempInstance()
                .debugOutput("PluginVersion.init: Before logging EU4 Version String address.");
            BytePattern.tempInstance()
                .debugOutput(format("PluginVersion.init: EU4 Version String found at 0x%x", address));
            BytePattern.tempInstance()
                .debugOutput("PluginVersion.init: After logging EU4 Version String address.");

            // 翻訳マップがロードされていることを確認 (最初のパッチ適用ステップ)
            BytePattern.tempInstance().debugOutput(format("PluginVersion.init: Translation map contains %d entries.", translationMap
                    .length));

            // バージョン検出のみを行い、パッチ適用は行わない（C++版の挙動に合わせる）
            BytePattern.tempInstance()
                .debugOutput("PluginVersion.init: EU4 Version String pattern found, but no patch applied (C++ behavior).");
            return true; // 検出成功
        }
        else
        {
            BytePattern.tempInstance()
                .debugOutput("PluginVersion.init: EU4 Version String pattern not found.");
            return false; // 失敗
        }
    default:
        BytePattern.tempInstance().debugOutput(format("PluginVersion.init: Unknown EU4 Version: %s", std
                .conv.to!string(options.eu4Version)));
        return false; // 失敗
    }
}

// 全てのフック処理を初期化する関数
bool init(EU4Ver eu4Version)
{ // 戻り値をDllErrorからboolに変更
    RunOptions options;
    options.eu4Version = eu4Version;

    return detectEu4Version(options); // boolの戻り値を直接返す
}
