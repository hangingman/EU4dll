module plugin.localization.entry;

import plugin.constant;
import plugin.input; // DllErrorとRunOptionsを使用するためインポート
import plugin.localization.common; // 共通変数・構造体を使用するため

// 各Injectorモジュールの関数をインポート
import plugin.localization.proc1_dummy;
import plugin.localization.battle_area;
import plugin.localization.heir_name;
import plugin.localization.name_order;
import plugin.localization.date_fmt;
import plugin.localization.space_fix;

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    _day.text[0] = cast(char)0xE;
    _day.text[1] = '\0';
    _day.len = 1;
    _day.len2 = 0xF;

    _year.text[0] = cast(char)0xF;
    _year.text[1] = '\0';
    _year.len = 1;
    _year.len2 = 0xF;

    _month.text[0] = cast(char)7;
    _month.text[1] = '\0';
    _month.len = 1;
    _month.len2 = 0xF;
    
    year = cast(size_t) &_year;
    month = cast(size_t)&_month;
    day = cast(size_t)&_day;

    // 関数アドレス取得
    result = result | localizationProc1Injector(options);

    // Battle of areaを逆転させる
    // 確認方法）敵軍と戦い、結果のポップアップのタイトルを確認する
    result = result | localizationProc2Injector(options);

    // MDEATH_HEIR_SUCCEEDS heir nameを逆転させる
    //result = result | localizationProc3Injector(options);

    // MDEATH_REGENCY_RULE heir nameを逆転させる
    // ※localizationProc1CallAddress2のhookもこれで実行している
    result = result | localizationProc4Injector(options);

    // nameを逆転させる
    // 確認方法）sub modを入れた状態で日本の大名を選択する。大名の名前が逆転しているかを確認する
    result = result | localizationProc5Injector(options);

    // 年号の表示がM, YからY年M
    // 確認方法）オスマンで画面上部の停戦アラートのポップアップの年号を確認する
    result = result | localizationProc6Injector(options);

    // 年号の表示がD M, YからY年MD日になる
    // 確認方法）スタート画面のセーブデータの日付を見る
    result = result | localizationProc7Injector(options);

    // 年号の表示がM YからY年Mになる
    // 確認方法）外交官のポップアップを表示し、年号を確認する
    result = result | localizationProc8Injector(options);

    // スペースを変更
    //result = result | localizationProc9Injector(options);

    return result;
}
