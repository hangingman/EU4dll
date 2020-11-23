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
