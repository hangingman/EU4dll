module plugin.dllmain;


import std.stdio;
import plugin.byte_pattern;


extern(C):


pragma(crt_constructor)
void hijack()
{
    writeln("this is hijacked!!!");
}


