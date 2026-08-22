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

    // テストケース1: 指定されたYAMLファイルから翻訳データをロードする
    {
        clearTranslationMap(); // 各テストケースの前にtranslationMapをクリア
        string testModDir = buildPath(environment.get("CWD"), "tests", "resources");
        
        // テスト用YAMLファイルが存在することを確認
        string testYamlPath = buildPath(testModDir, "test_translation.yml");
        assert(testYamlPath.exists, format("Test YAML file not found: %s", testYamlPath));

        loadTranslationMods(testModDir);

        translationMap.length.should.equal(5); // Includes the known menu translation observation key
        assert("GREETING_KEY" in translationMap, "GREETING_KEY should exist in translationMap");
        translationMap["GREETING_KEY"].value.should.equal("Hello, World!");
        assert("FAREWELL_KEY" in translationMap, "FAREWELL_KEY should exist in translationMap");
        translationMap["FAREWELL_KEY"].value.should.equal("Goodbye, World!");
        assert("EMPTY_VALUE_KEY" in translationMap, "EMPTY_VALUE_KEY should exist in translationMap");
        translationMap["EMPTY_VALUE_KEY"].value.should.equal("");
        assert("MENU_BAR_LOAD_GAME" in translationMap,
                "MENU_BAR_LOAD_GAME should exist in translationMap");
        translationMap["MENU_BAR_LOAD_GAME"].value.should.equal("ロード");
        // NON_EXISTENT_KEY はYAMLパーシングで直接キーとして追加されないためテストしない
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

    // テストケース4: 観測対象キーを複数指定し、空白と重複を除去する
    {
        auto keys = translationObservationKeys(" MENU_BAR_LOAD_GAME, MENU_BAR_QUIT, MENU_BAR_LOAD_GAME ");
        keys.should.equal(["MENU_BAR_LOAD_GAME", "MENU_BAR_QUIT"]);
    }

    // テストケース5: 観測対象キーが未指定なら既知のキーだけを使う
    {
        auto keys = translationObservationKeys("");
        keys.should.equal(["MENU_BAR_LOAD_GAME"]);
    }

    // テストケース6: ALLなら辞書の全キーを辞書順で返す
    {
        clearTranslationMap();
        translationMap["ZETA_KEY"] = TranslationData("ZETA_KEY", "zeta");
        translationMap["ALPHA_KEY"] = TranslationData("ALPHA_KEY", "alpha");
        translationMap["BETA_KEY"] = TranslationData("BETA_KEY", "beta");

        auto keys = translationObservationKeys(" ALL ");
        keys.should.equal(["ALPHA_KEY", "BETA_KEY", "ZETA_KEY"]);
        clearTranslationMap();
    }

    // テストケース7: BOM、ヘッダー補完、特殊スカラーキーを処理する
    {
        clearTranslationMap();
        auto variantTestModDir = buildPath(environment.get("CWD"), "tests", "translation_variant_mod");
        if (!variantTestModDir.exists)
            mkdir(variantTestModDir);

        auto variantYamlPath = buildPath(variantTestModDir, "variant.yml");
        write(variantYamlPath,
                "\xEF\xBB\xBFMENU_BAR_LOAD_GAME:0 \"ロード\"\n" ~
                "MENU_BAR_LOAD:1 \"ロード\"\n" ~
                "MENU_BAR_QUIT:2 \"ゲーム終了\"\n" ~
                 "MENU_BAR_SAVE_GAME:0 \"セーブ\"\n" ~
                 "MENU_BAR_GAME_OPTIONS:1 \"ゲームのオプション\"\n" ~
                 "MENU_BAR_CLOSE:3 \"閉じる\"\n" ~
                 "true:0 \"真\"\n" ~
                 "false:1 \"偽\"\n" ~
                 "null:2 \"空\"\n" ~
                 "YES:0 \"YES\"\n" ~
                 "NO:1 \"NO\"\n" ~
                 "on:0 \"オン\"\n" ~
                 "off:0 \"オフ\"\n");
        loadTranslationMods(variantTestModDir);

        translationMap.length.should.equal(13);
        translationMap["MENU_BAR_LOAD_GAME"].value.should.equal("ロード");
        translationMap["MENU_BAR_LOAD"].value.should.equal("ロード");
        translationMap["MENU_BAR_QUIT"].value.should.equal("ゲーム終了");
        translationMap["MENU_BAR_SAVE_GAME"].value.should.equal("セーブ");
        translationMap["MENU_BAR_GAME_OPTIONS"].value.should.equal("ゲームのオプション");
        translationMap["MENU_BAR_CLOSE"].value.should.equal("閉じる");
        translationMap["true"].value.should.equal("真");
        translationMap["false"].value.should.equal("偽");
        translationMap["null"].value.should.equal("空");
        translationMap["YES"].value.should.equal("YES");
        translationMap["NO"].value.should.equal("NO");
        translationMap["on"].value.should.equal("オン");
        translationMap["off"].value.should.equal("オフ");

        remove(variantYamlPath);
        rmdir(variantTestModDir);
        clearTranslationMap();
    }
}
