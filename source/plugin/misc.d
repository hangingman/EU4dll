module plugin.misc;


import plugin.constant;
import plugin.byte_pattern;
import std.stdio;
import std.format;


struct Misc
{
    
static:

    EU4Version getVersion()
    {        
        BytePattern b = BytePattern.tempInstance();
        b.findPattern("45 55 34 20 76 31 2E ? ? 2E ?");

        if (b.count() > 0)
            {
                b.debugOutput("count != 0");
            }
        else
            {
                b.debugOutput("count == 0");
            }
    
        return EU4Version.UNKNOWN;
    };
};
