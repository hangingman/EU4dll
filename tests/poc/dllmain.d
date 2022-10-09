module poc.dllmain;


import std.stdio;
import core.stdc.stdlib;
import plugin.byte_pattern;
import scriptlike.path.extras : Path;


extern(C):


pragma(crt_constructor)
void hijack()
{
    hijackProcess();
}

void hijackProcess()
{
    BytePattern.startLog("eu4jps");
    auto b = BytePattern.tempInstance();
    Path binPath = Path(__FILE__) ~ "libeu4dll-poc.so";
}
