# Memo

## Mod

[Mods - Europa Universalis 4 Wiki](https://eu4.paradoxwikis.com/Mods)

Modのインストールフォルダは以下:

```
Windows: ~\Documents\Paradox Interactive\Europa Universalis IV\mod\
GNU/Linux: ~/.local/share/Paradox Interactive/Europa Universalis IV/mod/
Mac: ~/Documents/Paradox Interactive/Europa Universalis IV/mod/
```

ちなみにワークショップで配布されるModは以下:

```
// 以下、debianの場合
~/.steam/debian-installation/steamapps/workshop/content/236850/[Workshop item ID]
```

## EU4

EU4本体のインストールフォルダは以下:

```
// 以下、debianの場合
~/.steam/debian-installation/steamapps/common/Europa Universalis IV
```

このへんはsteamのゲーム一覧からプロパティを選ぶことで確認できる

## EU4でこのdllを使う方法（予定）

- 一応以下の方法で.soをhijackできることが確認できた
- launcher-settings.jsonで指定できれば嬉しいができないっぽい

```
// 以下、debianの場合, libeu4dll.soをコピーしておく
$ cd ~/.steam/debian-installation/steamapps/common/Europa Universalis IV
$ LD_PRELOAD=./libeu4dll.so ./eu4
```

