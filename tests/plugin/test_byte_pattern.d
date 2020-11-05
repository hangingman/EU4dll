module plugin.test_byte_pattern;

import std.file : thisExePath;
import scriptlike.file.extras : existsAsFile, tryRemove;
import scriptlike.path.extras : Path;
import scriptlike.core;
import plugin.byte_pattern;

@("default constructor")
unittest
{
    auto b = new BytePattern();
    assert(b !is null);
}

@("startLog")
unittest
{
    Path logFilePath = Path(thisExePath()).up() ~ mixin(interp!"pattern_unittest.log");
    tryRemove(logFilePath);
    
    auto b = new BytePattern();
    b.startLog("unittest");
    assert(existsAsFile(logFilePath.toString()));
}

@("tempInstance")
unittest
{
    auto b = BytePattern.tempInstance();
    assert(b !is null);
}
