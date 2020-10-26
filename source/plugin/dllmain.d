module plugin.dllmain;


import std.stdio;
import core.stdc.stdlib;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc;


extern(C):


pragma(crt_constructor)
void hijack()
{
    // unittestのときは処理を何もしない
    version (unittest)
        {
            // NOP
        }
    else
        {
            hijackProcess();
        }
}

void hijackProcess()
{
    BytePattern.startLog("eu4jps");

    int success = 0;

    // versionを文字列から取得
    EU4Ver eu4Version = Misc.getVersion();

    // TODO: フォント関連の修正
    // success |= Font.init(eu4Version);

    // TODO: 本文テキスト表示の修正
    // success |= TextView.init(eu4Version);

    // TODO: マップ文字位置調整
    // success |= MapAdj.init(eu4Version);

    // TODO: マップ文字justify
    // success |= MapJustify.init(eu4Version);

    // TODO: マップ文字表示
    // success |= MapView.init(eu4Version);

    // TODO: その他
    // success |= Misc.init(eu4Version);

    // TODO: 入力修正
    // success |= Input.init(eu4Version);

    // TODO: IME修正
    // success |= IME.init(eu4Version);

    // TODO: ツールチップとボタン
    // success |= ButtonAndToolTip.init(eu4Version);

    // TODO: ツールチップ追加処理
    // success |= ToolTipApx.init(eu4Version);

    // TODO: マップ上のポップアップ文字
    // success |= PopupCharOnMap.init(eu4Version);

    // TODO: issue-19の修正
    // success |= InputIssue19.init(eu4Version);

    // TODO: イベントダイアログの修正とマップ上の修正
    // success |= EventDialog.init(eu4Version);

    // TODO: ファイルセーブ関連
    // success |= FileSave.init(eu4Version);

    // TODO: DateFormat(issue-66)の修正
    // success |= DateFormat.init(eu4Version);

    // TODO: Listの文字調整（issue-99）
    // success |= ListChars.init(eu4Version);

    // TODO: 名前の順序(issue-98)
    // success |= NameOrder.init(eu4Version);

    if (success == 0)
        {
            BytePattern.tempInstance().debugOutput("DLL [OK]");
        }
    else
        {
            BytePattern.tempInstance().debugOutput("DLL [NG]");
            exit(-1);
        }
}
