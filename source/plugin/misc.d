module plugin.misc;


import plugin.constant;
import plugin.byte_pattern;
import std.stdio;
import std.format;
import scriptlike.core;
import std.conv;


struct Misc
{
    struct EU4Version {
        // EU4 v1.30.4
        char[7] versionPrefix;
        ubyte ascii1;
        ubyte ascii2;
        ubyte dot;
        ubyte ascii3;

        const int calVer() {
            int ver = (ascii1 - 0x30) * 100 + (ascii2 - 0x30)*10 + (ascii3 - 0x30);
            return ver;
        }
    };

static:

    EU4Ver getVersion()
    {
        BytePattern b = BytePattern.tempInstance();
        b.findPattern("45 55 34 20 76 31 2E ? ? 2E ?");
        EU4Ver ver = EU4Ver.UNKNOWN;

        if (b.count() > 0)
            {
                const EU4Version minor = b.found!(EU4Version)();

                switch (minor.calVer()) {
                case 250:
                    ver = EU4Ver.v1_25_X;
                    break;
                case 260:
                    ver = EU4Ver.v1_26_X;
                    break;
                case 270:
                case 272:
                    ver = EU4Ver.v1_27_X;
                    break;
                case 280:
                    ver = EU4Ver.v1_28_X;
                    break;
                case 283:
                    ver = EU4Ver.v1_28_3;
                    break;
                default:
                    ver = EU4Ver.UNKNOWN;
                    break;
                }
            }

        b.debugOutput(std.conv.to!string(ver));
        return ver;
    };
};

// 相対アドレスを解決するヘルパー関数
size_t get_branch_destination_offset(void* address, int offset_size)
{
    // オフセットサイズに基づいて相対オフセットを読み取る
    // 通常は4バイト (int) が使われる
    if (offset_size == 4)
    {
        int relative_offset = *cast(int*)address;
        return cast(size_t)relative_offset;
    }
    // その他のオフセットサイズが必要な場合はここに追加
    else
    {
        // 未対応のオフセットサイズ
        return 0; // またはエラーをスロー
    }
}
