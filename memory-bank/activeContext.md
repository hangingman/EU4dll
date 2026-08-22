# Active Context

## 現在の焦点

Linux版EU4の文字列置換経路を、Ghidra先行ではなく実行時観測から特定する。

## 次の作業

- EU4本体で`LD_PRELOAD`によるロードと対象限定I/Oログを確認する。
- 既知文字列1件のランタイム追跡へ進む。

## 直近の完了

`Misc.getVersion()`の実行ファイル指定を、個人環境の絶対パスから既存の`BytePattern.setModule()`既定値へ変更した。既定値は`std.file.thisExePath()`で実行中の実行ファイルを解決する。

## 方針変更

FreeType/HarfBuzz、SDL/OpenGL描画API、Windows版アドレスの直接流用は前提にしない。

## 直近の完了

`tests/poc`に`fopen`の対象限定観測を追加した。`localisation`、`.yml`、`.yaml`、フォント拡張子だけをstderrへ出力し、通常のI/Oは記録しない。`make -C tests/poc`と`make test`、`make all`が成功した。
