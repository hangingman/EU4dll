# Active Context

## 現在の焦点

Linux版EU4の文字列置換経路を、Ghidra先行ではなく実行時観測から特定する。

## 次の作業

- `CTextSprite::SetText(...)` と `CGraphics::CreateTextSprite(...)` のヒットが `MENU_BAR_LOAD_GAME` に対応するかを、未確認ポインタの無条件読み取りなしで静的解析または安全な条件付き観測により確認する。

## 直近の完了

`Misc.getVersion()`の実行ファイル指定を、個人環境の絶対パスから既存の`BytePattern.setModule()`既定値へ変更した。既定値は`std.file.thisExePath()`で実行中の実行ファイルを解決する。

## 方針変更

FreeType/HarfBuzz、SDL/OpenGL描画API、Windows版アドレスの直接流用は前提にしない。

## 直近の完了

`tests/poc`に`fopen`の対象限定観測を追加した。`localisation`、`.yml`、`.yaml`、フォント拡張子だけをstderrへ出力し、通常のI/Oは記録しない。`make -C tests/poc`と`make test`、`make all`が成功した。

EU4本体を`make run`で起動し、メニュー到達・操作可能を確認した。相対パスの`pattern_eu4jps.log`はEU4インストール先に作成され、起動時の翻訳YAMLロードと`DLL [OK]`を確認できる。`fopen`観測PoCのstderrログは本体DLLにはまだ組み込んでいない。

## 今回の変更

`/tmp/eu4dll-sprite-trace.log`（45921 bytes）で `CGraphics::CreateTextSprite` 236回（tid=1、pc=`0x2079b00`）と `CTextSprite::SetText` 444回（tid=1、pc=`0x20d9da4`）を確認した。EU4 v1.37.5は正常終了し、MENU画面まで到達して「ロード」表示状態を確認した。短いTRACEは文字列引数を記録していないため、`MENU_BAR_LOAD_GAME`との直接対応、引数、文字列形式、寿命は未確認である。表示生成経路として現在最有力だが、因果関係は断定しない。

次の最小ステップでは、全 `PdxLocalize` テンプレート一括フック、`open`/`read` フック、インラインパッチを行わず、まず静的解析または安全な条件付き観測方法を検討する。

## これまでの変更

`MENU_BAR_LOAD_GAME`（`Load Game` / `ロード`）を既知観測対象に固定した。翻訳ロード完了時にこのキーだけを照会し、loaded/missing と値を1行記録する。ゲーム本体の `LocalizeAddLocalization`、`YmlParse`、`PdxLocalize` 系、`CTextBox` は安全な呼び出し境界を確認できないため、フックは追加していない。

## これまでの観測

前回の候補 `CTextBuffer::ChangeString()` と `CTextBox::ChangeString(CString const&)` は、breakpoint設定には成功したが `/tmp/eu4dll-candidate-trace.log`（9484 bytes）でTRACE 0件だった。今回の操作では呼ばれておらず、成功扱いにしない。続く `CTextBox::UpdateTextSprite()` と `CTextBox::ChangeString(CString const&, FontFormatting, bool)` もMENU画面までのTRACE 0件だったため除外した。新候補を `CTextSprite::SetText(...)` と `CGraphics::CreateTextSprite(...)` に更新し、各ヒットで `symbol/tid/pc` の1行だけを記録した。実機ヒットの対応関係と引数は未確認である。

実機トレースではlocalisation読み込み経路を確認したが、`CTextBox::ChangeTextBox`はヒットせず、表示時の既知キー追跡には至っていない。次は候補を一括で増やさず、表示更新に近い既存テキスト関数を1つずつ観測する。
