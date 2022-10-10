module poc.dllmain;


import std.stdio;
import core.stdc.stdlib;
import plugin.byte_pattern;
import scriptlike.path.extras : Path;
import std.mmfile;
import fluent.asserts;


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
    Path binPath = Path(__FILE__).up().up().up() ~ "dummy";

    MmFile mmf = new MmFile(binPath.toString(), MmFile.Mode.read, 0, null);
    with (b)
        {
            getModuleRanges(mmf);
            setPattern("48 65 6c 6c 6f"); // Hello
            findIndexes(binPath.toString());
            writeln(_results.length);
            writeln(_results[0].address);
            //assert(_results.length == 1);
            //assert(_results[0].address == 1);
        }
}
