module poc.dllmain;


import std.stdio;
import core.stdc.stdlib;
import plugin.byte_pattern;
import scriptlike.path.extras : Path;
import std.mmfile;


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
    Path binPath = Path(__FILE__) ~ "dummy";

    MmFile mmf = new MmFile(binPath.toString(), MmFile.Mode.readWrite, 0, null);

}
