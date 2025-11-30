module plugin.mod;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.process; // 環境変数を取得するため
import std.json; // JSONをパースするため
import std.array; // 動的配列操作のため
import plugin.byte_pattern; // debugOutputのため

// 翻訳データを保持する構造体
struct TranslationData {
    string key;
    string value;

    // JSONからデシリアライズするヘルパー関数
    static TranslationData opCast(JSONValue value) {
        return TranslationData(value["key"].str, value["value"].str);
    }
}

// 翻訳MODの全データを保持する連想配列
TranslationData[string] translationMap;


/**
 * 翻訳MODを読み込む関数。
 * 検出されたMODファイルの中からJSON形式の翻訳ファイルを特定し、その内容を読み込んでパースします。
 */
void loadTranslationMods(string customModDirPath = "")
{
    BytePattern.tempInstance().debugOutput("Searching for translation mods and loading JSON files...");

    string modDirPath;
    if (customModDirPath.empty) {
        string homeDir = environment.get("HOME");
        if (homeDir.empty) {
            throw new Exception("HOME environment variable is not set. Cannot determine mod directory.");
        }
        modDirPath = buildPath(homeDir, ".local", "share", "Paradox Interactive", "Europa Universalis IV", "mod");
    } else {
        modDirPath = customModDirPath;
    }

    BytePattern.tempInstance().debugOutput(format("Checking mod directory: %s", modDirPath));
    if (modDirPath.exists && modDirPath.isDir)
    {
        BytePattern.tempInstance().debugOutput(format("Found mod directory: %s", modDirPath));

        foreach (DirEntry entry; dirEntries(modDirPath, SpanMode.depth))
        {
            BytePattern.tempInstance().debugOutput(format("  Processing entry: %s (isDir: %s, isFile: %s)", entry.name, entry.isDir, entry.isFile));

            if (entry.isFile)
            {
                if (entry.name.endsWith(".json")) {
                    BytePattern.tempInstance().debugOutput(format("  Found JSON translation file: %s", entry.name));
                    try {
                        string filePath = entry.name;
                        BytePattern.tempInstance().debugOutput(format("  Reading JSON file: %s", filePath));
                        string jsonContent = readText(filePath);
                        BytePattern.tempInstance().debugOutput(format("  JSON content read. Length: %d", jsonContent.length));

                        JSONValue parsedJson = std.json.parseJSON(jsonContent);
                        BytePattern.tempInstance().debugOutput("  JSON parsed successfully.");

                        foreach (key, value; parsedJson.object) {
                            if (value.type == std.json.JSONType.object) {
                                string translationKey = key;
                                string translationValue = value["text"].get!string();
                                if (!translationKey.empty) {
                                    translationMap[translationKey] = TranslationData(translationKey, translationValue);
                                    BytePattern.tempInstance().debugOutput(format("    Loaded translation: %s = %s", translationKey, translationValue));
                                }
                            } else {
                                BytePattern.tempInstance().debugOutput(format("    Skipping non-object JSON value for key: %s", key));
                            }
                        }
                        BytePattern.tempInstance().debugOutput(format("  Successfully loaded and parsed JSON from %s", entry.name));
                    } catch (std.json.JSONException e) {
                        BytePattern.tempInstance().debugOutput(format("  Error parsing JSON from %s: %s", entry.name, e.msg));
                    } catch (FileException e) {
                        BytePattern.tempInstance().debugOutput(format("  Error reading file %s: %s", entry.name, e.msg));
                    }
                } else {
                    BytePattern.tempInstance().debugOutput(format("  Found other mod file: %s", entry.name));
                }
            }
            else if (entry.isDir)
            {
                BytePattern.tempInstance()
                    .debugOutput(format("  Found mod directory (recursive): %s", entry.name));
            }
        }
        BytePattern.tempInstance().debugOutput(format("Total translations loaded: %d", translationMap.length));
    }
    else
    {
        BytePattern.tempInstance().debugOutput(format("Mod directory not found: %s", modDirPath));
    }
}
