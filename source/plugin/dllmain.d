module plugin.dllmain;


import std.stdio;
import core.stdc.stdlib;
import plugin.byte_pattern;


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


