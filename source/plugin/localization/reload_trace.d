module plugin.localization.reload_trace;

import core.sys.linux.sys.mman;
import core.stdc.string : memcpy;
import std.exception : enforce;
import std.format : format;
import std.logger;
import plugin.byte_pattern;
import plugin.constant;
import plugin.patcher.patcher : makeJmp, patch_memory;

private enum size_t CallPatchLength = 5;
private __gshared bool reloadTraceActive;
private __gshared bool function() reloadOriginal;
private __gshared bool reloadTraceInstalled;
private __gshared ubyte[8] reloadOriginalBytes;

private bool fitsRel32(void* fromAddress, void* toAddress)
{
    auto distance = cast(long) toAddress - (cast(long) fromAddress + cast(long) CallPatchLength);
    return distance >= -2147483648L && distance <= 2147483647L;
}

private void* makeEntryTrampoline(void* nearAddress, void* callback)
{
    auto pageSize = 4096UL;
    auto hint = cast(void*)(cast(size_t) nearAddress & ~(pageSize - 1));
    auto memory = mmap(hint, 16, PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
    enforce(memory !is MAP_FAILED, "mmap for ReloadPdxLocalize entry trampoline failed");

    auto code = cast(ubyte*) memory;
    auto target = cast(size_t) callback;
    code[0 .. 10] = [0x48, 0xb8,
        cast(ubyte)(target >> 0), cast(ubyte)(target >> 8),
        cast(ubyte)(target >> 16), cast(ubyte)(target >> 24),
        cast(ubyte)(target >> 32), cast(ubyte)(target >> 40),
        cast(ubyte)(target >> 48), cast(ubyte)(target >> 56)];
    code[10 .. 12] = [0xff, 0xe0];
    return memory;
}

private void* makeOriginalTrampoline(void* target)
{
    auto memory = mmap(null, 32, PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
    enforce(memory !is MAP_FAILED, "mmap for ReloadPdxLocalize original trampoline failed");

    auto code = cast(ubyte*) memory;
    memcpy(code, target, 8);
    auto resume = cast(size_t) target + 8;
    code[8 .. 18] = [0x48, 0xb8,
        cast(ubyte)(resume >> 0), cast(ubyte)(resume >> 8),
        cast(ubyte)(resume >> 16), cast(ubyte)(resume >> 24),
        cast(ubyte)(resume >> 32), cast(ubyte)(resume >> 40),
        cast(ubyte)(resume >> 48), cast(ubyte)(resume >> 56)];
    code[18 .. 20] = [0xff, 0xe0];
    return memory;
}

private extern(C) bool reloadTraceCallback()
{
    auto original = reloadOriginal;
    if (reloadTraceActive)
        return original();

    reloadTraceActive = true;
    log(LogLevel.info, "[DIAGNOSTIC] ReloadPdxLocalize call enter");
    auto result = original();
    log(LogLevel.info, format("[DIAGNOSTIC] ReloadPdxLocalize call return result=%s", result));
    reloadTraceActive = false;
    return result;
}

void initReloadTrace(EU4Ver eu4Version)
{
    if (eu4Version != EU4Ver.v1_37_5)
        return;

    auto functionPattern = BytePattern.tempInstance();
    functionPattern.findPattern("55 41 56 53 48 83 EC 20 E8 7A 62 37 00");
    if (functionPattern.count() != 1)
    {
        log(LogLevel.error, format("[DIAGNOSTIC] ReloadPdxLocalize target match count=%s", functionPattern.count()));
        return;
    }
    auto target = cast(void*) functionPattern.getFirst().address();
    memcpy(reloadOriginalBytes.ptr, target, reloadOriginalBytes.length);
    reloadOriginal = cast(bool function()) makeOriginalTrampoline(target);

    if (reloadTraceInstalled)
        return;

    auto entry = makeEntryTrampoline(target, cast(void*) &reloadTraceCallback);
    auto targetAddress = cast(size_t) target;
    auto entryAddress = cast(size_t) entry;
    auto distance = cast(long) entryAddress - (cast(long) targetAddress + CallPatchLength);
    auto fits = fitsRel32(target, entry);
    log(LogLevel.info, format("[DIAGNOSTIC] ReloadPdxLocalize trampoline target=0x%x entry=0x%x distance=%d fits=%s",
        targetAddress, entryAddress, distance, fits ? "true" : "false"));
    if (!fits)
    {
        log(LogLevel.error, "[DIAGNOSTIC] ReloadPdxLocalize entry exceeds rel32");
        return;
    }

    patch_memory(target, makeJmp(target, entry) ~ cast(ubyte[])[0x90, 0x90, 0x90]);
    reloadTraceInstalled = true;
    log(LogLevel.info, format("[DIAGNOSTIC] ReloadPdxLocalize hook installed target=0x%x entry=0x%x",
        cast(size_t) target, cast(size_t) entry));
}
