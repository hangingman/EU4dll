module plugin.mod;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.process; // 環境変数を取得するため
import dyaml.loader; // YAMLをパースするため
import dyaml.node; // YAMLノードとNodeIDを扱うため
import dyaml.exception; // YAMLパース例外を扱うため
import std.uni; // toUTF8 for unicode handling

// YAMLパーサーのユーティリティ関数
private string getScalarValue(const Node value)
{
    if (value.nodeID == NodeID.scalar)
    {
        // Nodeからのスカラー値取得はas!stringを使用
        return value.as!string; // string型なのでtoUTF8は不要
    }
    return "";
}

import std.array; // 動的配列操作のため
import plugin.byte_pattern; // debugOutputのため

// 翻訳データを保持する構造体
struct TranslationData
{
    string key;
    string value;
} // TranslationData structの閉じ括弧を追加

// 翻訳MODの全データを保持する連想配列
TranslationData[string] translationMap;

/**
 * 翻訳MODを読み込む関数。
 * 検出されたMODファイルの中からYAML形式の翻訳ファイルを特定し、その内容を読み込んでパースします。
 */
void loadTranslationMods(string customModDirPath = "")
{
    BytePattern.tempInstance()
        .debugOutput("Searching for translation mods and loading YAML files...");

    string modDirPath;
    if (customModDirPath.empty)
    {
        string homeDir = environment.get("HOME");
        if (homeDir.empty)
        {
            throw new Exception(
                "HOME environment variable is not set. Cannot determine mod directory.");
        }
        modDirPath = buildPath(homeDir, ".local", "share", "Paradox Interactive", "Europa Universalis IV", "mod");
    }
    else
    {
        modDirPath = customModDirPath;
    }

    BytePattern.tempInstance().debugOutput(format("Checking mod directory: %s", modDirPath));
    if (modDirPath.exists && modDirPath.isDir)
    {
        BytePattern.tempInstance().debugOutput(format("Found mod directory: %s", modDirPath));

        int jsonFileCount = 0;
        foreach (DirEntry entry; dirEntries(modDirPath, SpanMode.depth))
        {
            if (entry.isFile)
            {
                if (entry.name.endsWith(".yml"))
                {
                    jsonFileCount++; // YAMLファイル数としてカウント
                    try
                    {
                        string filePath = entry.name;
                        string yamlContent = readText(filePath);

                        // YAMLをパース (Loader structを使用)
                        auto loader = dyaml.loader.Loader.fromString(yamlContent, filePath); // ファイル名を渡す
                        if (loader.empty) // ロードするドキュメントがない場合
                        {
                             BytePattern.tempInstance()
                                .debugOutput(format("  Warning: %s contains no YAML documents.", entry.name));
                             continue;
                        }
                        auto rootNode = loader.load(); // 最初のドキュメントのルートノードを取得

                        if (rootNode.empty) // ロードされたノードが空の場合
                        {
                            BytePattern.tempInstance()
                                .debugOutput(format("  Warning: %s is empty or invalid YAML.", entry.name));
                            continue;
                        }

                        // EU4のlocalisationファイルの構造を想定 (例: l_english: KEY: "Value")
                        if (rootNode.nodeID == NodeID.mapping)
                        {
                            foreach (langPair; rootNode.mapping()) // rootNode.mappingはNode.mappingを返す
                            {
                                auto langKey = langPair.key;
                                auto langValue = langPair.value;
                                if (langValue.nodeID == NodeID.mapping)
                                {
                                    foreach (pair; langValue.mapping())
                                    {
                                        if (pair.value.nodeID == NodeID.scalar)
                                        {
                                            string valueStr = pair.value.as!string;
                                                string keyStr = pair.key.as!string;
                                                translationMap[keyStr] = TranslationData(keyStr, valueStr);
                                        }
                                    }
                                }
                            }
                        }
                        BytePattern.tempInstance()
                            .debugOutput(format("  Successfully loaded and parsed YAML from %s", entry
                                    .name));
                    }
                    catch (dyaml.exception.ParserException e)
                    {
                        BytePattern.tempInstance()
                            .debugOutput(format("  Error parsing YAML from %s: %s", entry.name, e
                                    .msg));
                    }
                    catch (FileException e)
                    {
                        BytePattern.tempInstance()
                            .debugOutput(format("  Error reading file %s: %s", entry.name, e.msg));
                    }
                    catch (Exception e)
                    {
                        BytePattern.tempInstance()
                            .debugOutput(format("  An unexpected error occurred while processing %s: %s", entry.name, e
                                    .msg));
                    }
                }
            }
        }
        BytePattern.tempInstance()
            .debugOutput(format("Total YAML translation files loaded: %d", jsonFileCount));
        BytePattern.tempInstance().debugOutput(format("Total translations added to map: %d", translationMap
                .length));
    }
    else
    {
        BytePattern.tempInstance().debugOutput(format("Mod directory not found: %s", modDirPath));
    }
}
