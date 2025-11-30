module plugin.mod;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.process; // 環境変数を取得するため
import plugin.byte_pattern; // debugOutputのため

/**
 * 翻訳MODを読み込むダミー関数。
 * 実際には、ファイルの解析やデータ構造への格納が必要になります。
 */
void loadTranslationMods()
{
    BytePattern.tempInstance().debugOutput("Searching for translation mods...");

    // Linux環境でのEU4のMODディレクトリパス
    // "~/.local/share/Paradox Interactive/Europa Universalis IV/mod/"
    // HOME環境変数からホームディレクトリを取得
    string homeDir = environment.get("HOME");
    if (homeDir.empty) {
        throw new Exception("HOME environment variable is not set. Cannot determine mod directory.");
    }
    string modDirPath = buildPath(homeDir, ".local", "share", "Paradox Interactive", "Europa Universalis IV", "mod");

    if (modDirPath.exists && modDirPath.isDir) // ディレクトリが存在し、かつそれがディレクトリであることを確認
    {
        BytePattern.tempInstance().debugOutput(format("Found mod directory: %s", modDirPath));

        foreach (DirEntry entry; dirEntries(modDirPath, SpanMode.depth)) // kind引数を省略
        {
            if (entry.isFile)
            {
                BytePattern.tempInstance().debugOutput(format("  Found mod file: %s", entry.name));
                // TODO: ここでmodファイルを読み込み、解析する
            }
            else if (entry.isDir)
            {
                BytePattern.tempInstance()
                    .debugOutput(format("  Found mod directory (recursive): %s", entry.name));
            }
        }
    }
    else
    {
        BytePattern.tempInstance().debugOutput(format("Mod directory not found: %s", modDirPath));
    }
}
