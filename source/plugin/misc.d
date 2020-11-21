module plugin.misc;


import plugin.constant;
import plugin.byte_pattern;


EU4Version getVersion()
{
    BytePattern.tempInstance().findPattern("45 55 34 20 76 31 2E ? ? 2E ?");
    return EU4Version.UNKNOWN;
};
