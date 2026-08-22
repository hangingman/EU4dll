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
import std.logger; // std.loggerのために追加
import std.algorithm : canFind, sort;

private string normalizeLocalizationYaml(string yamlContent)
{
    // d-yaml does not treat the UTF-8 BOM as part of the document header.
    if (yamlContent.startsWith("\xEF\xBB\xBF"))
        yamlContent = yamlContent[3 .. $];

    // EU4 uses KEY:0 "Value" through KEY:9 "Value". Convert the numeric
    // version suffix before handing the content to the YAML parser.
    foreach (version_; 0 .. 10)
        yamlContent = yamlContent.replace(format(":%d \"", version_), ": \"");

    // EU4 keys are strings, but YAML 1.1 resolves these words as scalar
    // booleans/null. Quote only the affected mapping keys so d-yaml does not
    // merge distinct localisation keys (for example, YES and on).
    string[] yamlSpecialKeys = ["true", "false", "null", "yes", "no", "on", "off"];
    string[] normalizedLines;
    foreach (line; yamlContent.splitLines())
    {
        auto colon = line.indexOf(':');
        if (colon > 0)
        {
            auto key = line[0 .. colon].strip;
            if (!key.empty && key[0] != '"' && key[0] != '\''
                    && yamlSpecialKeys.canFind(key.toLower))
            {
                auto indentationLength = line[0 .. colon].length - key.length;
                auto indentation = line[0 .. indentationLength];
                line = indentation ~ "\"" ~ key ~ "\":" ~ line[colon + 1 .. $];
            }
        }
        normalizedLines ~= line;
    }
    yamlContent = normalizedLines.join("\n");

    if (!yamlContent.strip().startsWith("l_english:"))
    {
        string indentedContent;
        foreach (line; yamlContent.splitLines())
            indentedContent ~= " " ~ line ~ "\n";
        yamlContent = "l_english:\n" ~ indentedContent;
    }

    return yamlContent;
}

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

// 翻訳データを保持する構造体
struct TranslationData
{
    string key;
    string value;
} // TranslationData structの閉じ括弧を追加

// 翻訳MODの全データを保持する連想配列
TranslationData[string] translationMap;

/**
 * Return the keys to inspect after translation loading.
 *
 * The default remains the one key already observed on the real game. `ALL`
 * opts in to a sorted enumeration of the loaded dictionary. These are
 * dictionary observations, not evidence of game display calls.
 */
string[] translationObservationKeys(string configuredKeys)
{
    enum defaultKey = "MENU_BAR_LOAD_GAME";
    if (configuredKeys.empty)
        return [defaultKey];

    if (configuredKeys.strip == "ALL")
    {
        auto keys = translationMap.keys;
        keys.sort;
        return keys;
    }

    string[] keys;
    foreach (rawKey; configuredKeys.split(","))
    {
        auto key = rawKey.strip;
        if (!key.empty && !keys.canFind(key))
            keys ~= key;
    }
    return keys.empty ? [defaultKey] : keys;
}

/**
 * Record dictionary observations for selected keys. ALL deliberately
 * enumerates the already-loaded map and performs the same direct lookups.
 */
void logTranslationObservations()
{
    auto configuredKeys = environment.get("EU4DLL_TRANSLATION_OBSERVATION_KEYS");
    auto keys = translationObservationKeys(configuredKeys);
    if (configuredKeys.strip == "ALL")
        std.logger.info(format("Translation observation: mode=all key_count=%d", keys.length));

    foreach (key; keys)
    {
        auto translation = key in translationMap;
        if (translation is null)
        {
            std.logger.info(format("Translation observation: key=%s status=missing", key));
            continue;
        }

        std.logger.info(format("Translation observation: key=%s status=loaded value=%s", key,
                translation.value));
    }
}

/**
 * 翻訳MODを読み込む関数。
 * 検出されたMODファイルの中からYAML形式の翻訳ファイルを特定し、その内容を読み込んでパースします。
 */
void loadTranslationMods(string customModDirPath = "")
{
    std.logger.info("Searching for translation mods and loading YAML files...");

    string modDirPath;
    if (customModDirPath.empty)
    {
        string homeDir = environment.get("HOME");
        if (homeDir.empty)
        {
            std.logger.error("HOME environment variable is not set. Cannot determine mod directory.");
            logTranslationObservations();
            return; // エラーなので処理を中断
        }
        modDirPath = buildPath(homeDir, ".local", "share", "Paradox Interactive", "Europa Universalis IV", "mod");
    }
    else
    {
        modDirPath = customModDirPath;
    }

    std.logger.info(format("Checking mod directory: %s", modDirPath));
    if (modDirPath.exists && modDirPath.isDir)
    {
        std.logger.info(format("Found mod directory: %s", modDirPath));

        int yamlFileCount = 0;
        foreach (DirEntry entry; dirEntries(modDirPath, SpanMode.depth))
        {
            if (entry.isFile)
            {
                if (entry.name.endsWith(".yml"))
                {
                    yamlFileCount++; // YAMLファイル数としてカウント
                    string filePath = entry.name; // DirEntry.name を直接使用
                    try
                    {
                        string yamlContent = readText(filePath);

                        auto headerContent = yamlContent;
                        if (headerContent.startsWith("\xEF\xBB\xBF"))
                            headerContent = headerContent[3 .. $];
                        auto hadLanguageHeader = headerContent.strip().startsWith("l_english:");
                        yamlContent = normalizeLocalizationYaml(yamlContent);
                        if (!hadLanguageHeader)
                            std.logger.info(format("  Warning: 'l_english:' prefix missing in %s. Attempting to add it.", entry.name));

                        // YAMLをパース (Loader structを使用)
                        auto loader = dyaml.loader.Loader.fromString(yamlContent, filePath); // ファイル名を渡す
                        if (loader.empty) // ロードするドキュメントがない場合
                        {
                            std.logger.info(format("  Warning: %s contains no YAML documents.", entry.name));
                            continue;
                        }
                        auto rootNode = loader.load(); // 最初のドキュメントのルートノードを取得

                        if (rootNode.empty) // ロードされたノードが空の場合
                        {
                            std.logger.info(format("  Warning: %s is empty or invalid YAML.", entry.name));
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
                        std.logger.info(format("  Successfully loaded and parsed YAML from %s", entry.name));
                    }
                    catch (YAMLException e)
                    {
                        // YAMLExceptionから行番号を取得する方法を修正
                        // dyaml 0.10.0のYAMLExceptionにはstartMarkプロパティがない可能性があるため、
                        // e.msgから情報を抽出するか、よりジェネリックなエラーメッセージにする
                        std.logger.error(format("  Error parsing YAML from %s: %s", entry.name, e.msg));
                    }
                    catch (Exception e)
                    {
                        std.logger.error(format("  An unexpected error occurred while processing %s: %s", entry.name, e.msg));
                    }
                }
            }
        }
        std.logger.info(format("Total YAML translation files loaded: %d", yamlFileCount));
        std.logger.info(format("Total translations added to map: %d", translationMap.length));
    }
    else
    {
        std.logger.info(format("Mod directory not found: %s", modDirPath));
    }

    logTranslationObservations();
}
