module poc.dllmain;


import core.stdc.stdio : FILE;
import core.stdc.string : strlen, strstr;
import core.sys.posix.dlfcn : dlsym;
import core.sys.posix.unistd : write;


extern(C):

private alias FopenFunction = FILE* function(const(char)*, const(char)*);
__gshared FopenFunction nextFopen;
__gshared bool resolvingFopen;
enum void* RTLD_NEXT = cast(void*) -1;

private bool endsWith(const(char)* path, string suffix)
{
    auto pathLength = strlen(path);
    if (pathLength < suffix.length)
        return false;

    foreach (i; 0 .. suffix.length)
        if (path[pathLength - suffix.length + i] != suffix[i])
            return false;
    return true;
}

private bool isObservedPath(const(char)* path)
{
    return strstr(path, "localisation") !is null ||
        strstr(path, "font") !is null ||
        endsWith(path, ".yml") || endsWith(path, ".yaml") ||
        endsWith(path, ".ttf") || endsWith(path, ".otf") ||
        endsWith(path, ".ttc") || endsWith(path, ".fnt") ||
        endsWith(path, ".fon") || endsWith(path, ".woff") ||
        endsWith(path, ".woff2");
}

private void writeHookLog(const(char)* path)
{
    auto prefix = "[eu4dll-poc] fopen: ";
    write(2, prefix.ptr, prefix.length);
    write(2, path, strlen(path));
    write(2, "\n".ptr, 1);
}

// TODO: Deliberately limited to fopen; do not add open/openat/read hooks without
// evidence that this narrow observation point is insufficient.
FILE* fopen(const(char)* path, const(char)* mode)
{
    if (nextFopen is null && !resolvingFopen)
    {
        resolvingFopen = true;
        nextFopen = cast(FopenFunction) dlsym(RTLD_NEXT, "fopen".ptr);
        resolvingFopen = false;
    }

    if (path !is null && isObservedPath(path))
        writeHookLog(path);

    return nextFopen is null ? null : nextFopen(path, mode);
}


pragma(crt_constructor)
void hijack()
{
    hijackProcess();
}

void hijackProcess()
{
    auto message = "[eu4dll-poc] loaded (fopen observation enabled)\n";
    write(2, message.ptr, message.length);
}
