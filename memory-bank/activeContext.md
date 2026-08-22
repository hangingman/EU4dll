# Active Context

## 現在の焦点

Linux版EU4の文字列置換経路を、Ghidra先行ではなく実行時観測から特定する。

## 次の作業

- `LD_PRELOAD`による最小ロードログを確認する。
- localisation・フォント関連I/Oの対象限定観測を実装する。
- 既知文字列1件のランタイム追跡へ進む。

## 直近の完了

`Misc.getVersion()`の実行ファイル指定を、個人環境の絶対パスから既存の`BytePattern.setModule()`既定値へ変更した。既定値は`std.file.thisExePath()`で実行中の実行ファイルを解決する。

## 方針変更

FreeType/HarfBuzz、SDL/OpenGL描画API、Windows版アドレスの直接流用は前提にしない。
