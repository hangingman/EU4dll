# Active Context

## 現在の焦点

EU4 v1.37.5 Linux版で、constructor中の翻訳ロードを避け、EU4本体の正規localisation処理後に一度だけ翻訳ロードを診断する境界を設計する。実装はまだ行わない。

## 確定した実機結果（2026/08/23）

- DLL付きEU4 v1.37.5を翻訳ロード有効で起動し、EU4は正常終了した。
- `/tmp/eu4dll-localization-boundary.log` の `TRACE_LOCALIZE` は29行で、全件 `tid=1` だった。
- ヒット数は `PdxLocalizeSetup` 1回、`PdxLocalizeInitialize` 2回（各入口・復帰）、`PdxLocalizeReadFolder` 2回（入口）、`LocalizeAddLocalizationYAMLBuffer` 10回（入口）、`YmlParse` 10回（入口）、`ReloadPdxLocalize` 1回（入口・復帰）。
- 初回順序は `PdxLocalizeSetup` → `PdxLocalizeInitialize` 入口 → `LocalizeAddLocalizationYAMLBuffer`/`YmlParse` → `PdxLocalizeInitialize` 復帰 → `PdxLocalizeReadFolder` → 補助10件。
- 次回順序は `ReloadPdxLocalize` 入口 → `PdxLocalizeInitialize` 入口・復帰 → `PdxLocalizeReadFolder` → `ReloadPdxLocalize` 復帰。
- 静的検証 `bash -n`、GDB `/bin/true`、`git diff --check` は成功した。

## 設計判断

- `ReloadPdxLocalize` 復帰は遅延ロード境界の候補とする。ただし今回の観測だけでは、localisation構築完了、再入安全性、翻訳ロード実行安全性を証明しない。候補として記録するが、安全とは判定しない。
- `PdxLocalizeInitialize` 復帰単独は、その直後に `PdxLocalizeReadFolder` が続くため完了境界とみなさない。
- 次作業はSetText置換ではなく、`ReloadPdxLocalize` 復帰後に実行する最小・一回限り・翻訳ロードのみの診断PoC設計とする。まず翻訳ロードをconstructorでスキップし、正規localisation後の候補境界でロードする方法を検討する。
- PoC要件は再入ガード、`tid=1`限定、例外・失敗時のゲーム原文維持、ログマーカー、無効化可能性とする。実装はまだ行わない。

## 保留

- 既存のSetText置換、AOB、トランポリン、Open/read、全`PdxLocalize`一括、Windows流用は保留する。
- `translationMap`のロード結果、関数ヒット、正常終了だけでは、ゲーム表示値との対応や置換可能性を証明しない。
- ログ原本: `/tmp/eu4dll-localization-boundary.log`。

## 次の作業

1. constructorの翻訳ロードをスキップし、`ReloadPdxLocalize`復帰後へ接続する診断PoCの最小設計を作る。
2. 一回限り実行、再入・スレッド制限、失敗時フォールバック、ログマーカー、無効化手段を設計上検証する。
3. 設計根拠が揃うまでソースコードとSetText置換は変更しない。

## 検証状態

- 今回の実機ログと静的検証結果を `progress.md` と `details/runtime_trace.md` に記録する。
- 既存の未コミット追跡スクリプトは変更・削除しない。
- コミットは行わない。

## 変更していない前提

- 現在のDLLは翻訳YAMLを独自の`translationMap`へロードするだけで、SetText置換は実装していない。
- `EU4DLL_SKIP_TRANSLATIONS=1` の診断分岐は既存実装であり、通常動作の既定値は変更しない。
- ホームディレクトリをリポジトリ文書へ追加しない。