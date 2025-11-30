module tests.plugin.test_mod;

import fluent.asserts;
import std.file;
import std.path;
import std.array;
import std.process; // for environment.set/get
import plugin.mod; // test target
import plugin.byte_pattern; // debugOutputのため
import std.format; // format関数を使うために追加

unittest {
    // 各テストの前にtranslationMapをクリア
    void clearTranslationMap() {
        translationMap.clear();
    }

    // テストケース1: 指定されたJSONファイルから翻訳データをロードする
    {
        clearTranslationMap(); // 各テストケースの前にtranslationMapをクリア
        string testModDir = buildPath(environment.get("CWD"), "tests", "resources");
        
        // テスト用JSONファイルが存在することを確認
        string testJsonPath = buildPath(testModDir, "test_translation.json");
        assert(testJsonPath.exists, format("Test JSON file not found: %s", testJsonPath));

        loadTranslationMods(testModDir);

        translationMap.length.should.equal(4); // GREETING_KEY, FAREWELL_KEY, EMPTY_VALUE_KEY, NON_EXISTENT_KEY
        assert("GREETING_KEY" in translationMap, "GREETING_KEY should exist in translationMap");
        translationMap["GREETING_KEY"].value.should.equal("Hello, World!");
        assert("FAREWELL_KEY" in translationMap, "FAREWELL_KEY should exist in translationMap");
        translationMap["FAREWELL_KEY"].value.should.equal("Goodbye, World!");
        assert("EMPTY_VALUE_KEY" in translationMap, "EMPTY_VALUE_KEY should exist in translationMap");
        translationMap["EMPTY_VALUE_KEY"].value.should.equal("");
        assert("NON_EXISTENT_KEY" in translationMap, "NON_EXISTENT_KEY should exist in translationMap");
        translationMap["NON_EXISTENT_KEY"].value.should.equal("This should not be loaded directly by a separate JSON parsing function if not explicitly handled");
    }

    // テストケース2: 空のmodディレクトリを処理し、エラーをスローしない
    {
        clearTranslationMap(); // 各テストケースの前にtranslationMapをクリア
        string emptyTestModDir = buildPath(environment.get("CWD"), "tests", "empty_mod_dir");
        if (!emptyTestModDir.exists) {
            mkdir(emptyTestModDir);
        }

        loadTranslationMods(emptyTestModDir);
        translationMap.length.should.equal(0);
        rmdir(emptyTestModDir); // クリーンアップ
    }

    // テストケース3: 存在しないmodディレクトリを処理し、エラーをスローしない
    {
        clearTranslationMap(); // 各テストケースの前にtranslationMapをクリア
        string nonExistentModDir = buildPath(environment.get("CWD"), "tests", "non_existent_mod_dir");
        // ディレクトリが存在しないことを確認
        assert(!nonExistentModDir.exists, format("Directory should not exist: %s", nonExistentModDir));

        loadTranslationMods(nonExistentModDir);
        translationMap.length.should.equal(0);
    }
}
