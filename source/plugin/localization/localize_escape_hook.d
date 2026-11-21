module plugin.localization.localize_escape_hook;

// Localisation-load escape hook: entry hook on the game's
// LocalizeYmlAddKey (Linux v1.37.5) that escape-encodes non-ASCII
// yml values at load time instead of letting the game's
// ConvertUTF8ToLatin1 turn every Japanese character into '?'.
// Opt-in via EU4DLL_LOCALIZE_ESCAPE=1. The survey that identified
// the conversion point and the disassembly this file is built on
// are recorded in memory-bank/details/
// localisation_load_conversion_survey.md and
// memory-bank/details/localize_escape_hook.md.
//
// Behaviour, mirroring the original function:
// - the byte flag at pData+0x38 clear -> call the original
//   unchanged (it stores the raw UTF-8 pair itself);
// - flag set, key not pure ASCII -> delegate to the original;
// - flag set, value pure ASCII -> delegate to the original (so the
//   converter's notification lambda and every other side effect
//   stay exactly as before);
// - flag set, value has non-ASCII bytes and encodes cleanly ->
//   store key + escaped value through SLanguageData::
//   AddKeyValuePair with the same arguments the original's
//   converting branch builds, and skip the original entirely.

import plugin.constant : EU4Ver;
import plugin.localization.escape_codec : encodeUtf8ToEscaped;

/// True when every byte is below 0x80.
bool isPureAscii(const(ubyte)[] bytes)
{
    foreach (b; bytes)
        if (b >= 0x80)
            return false;
    return true;
}

enum LocalizePlanAction
{
    delegateToOriginal,
    storeEscaped,
}

enum LocalizeDelegateReason
{
    none,
    nonAsciiKey,
    asciiValue,
    unencodableValue,
}

struct LocalizeStorePlan
{
    LocalizePlanAction action;
    LocalizeDelegateReason reason; // valid when delegating
    ubyte[] escapedValue; // valid when storing
}

/// Text form of a delegate reason, used in the once-per-reason log.
string localizeDelegateReasonText(LocalizeDelegateReason reason)
{
    final switch (reason)
    {
    case LocalizeDelegateReason.none:
        return "none";
    case LocalizeDelegateReason.nonAsciiKey:
        return "non-ascii-key";
    case LocalizeDelegateReason.asciiValue:
        return "ascii-value";
    case LocalizeDelegateReason.unencodableValue:
        return "unencodable-value";
    }
}

/// Pure decision: given the key and value bytes exactly as read
/// from the two CUTF8Strings, decide whether the hook stores an
/// escaped pair itself or delegates to the original function.
LocalizeStorePlan planLocalizeStore(const(ubyte)[] key, const(ubyte)[] value)
{
    LocalizeStorePlan plan;
    if (!isPureAscii(key))
    {
        plan.action = LocalizePlanAction.delegateToOriginal;
        plan.reason = LocalizeDelegateReason.nonAsciiKey;
        return plan;
    }
    if (isPureAscii(value))
    {
        plan.action = LocalizePlanAction.delegateToOriginal;
        plan.reason = LocalizeDelegateReason.asciiValue;
        return plan;
    }
    ubyte[] escaped;
    if (!encodeUtf8ToEscaped(cast(const(char)[]) value, escaped))
    {
        plan.action = LocalizePlanAction.delegateToOriginal;
        plan.reason = LocalizeDelegateReason.unencodableValue;
        return plan;
    }
    plan.action = LocalizePlanAction.storeEscaped;
    plan.reason = LocalizeDelegateReason.none;
    plan.escapedValue = escaped;
    return plan;
}

// Offsets inside LocalizeYmlAddKey (v1.37.5, entry VA 0x23671a1),
// from the full disassembly recorded in
// memory-bank/details/localize_escape_hook.md. The two derivations
// below are pure so the byte checks and the rel32 arithmetic are
// pinned by unittests against the real instruction bytes.
private enum size_t FlagLoadOffset = 0x16; // mov rax, [rip+disp32] -> pData global
private enum size_t FlagCmpOffset = 0x1D; // cmpb $0, 0x38(%rax)
private enum size_t StoreMovOffset = 0xAE; // mov %r14d, %r8d, before the store call
private enum size_t StoreCallOffset = 0xB1; // call AddKeyValuePair (E8 rel32)
private enum size_t TailJmpOffset = 0xE0; // jmp AddKeyValuePair (E9 rel32), flag-clear path
private enum size_t PrefixBytesNeeded = TailJmpOffset + 5;

private bool matchBytes(const(ubyte)[] code, size_t offset, const(ubyte)[] expected)
{
    if (code.length < offset + expected.length)
        return false;
    return code[offset .. offset + expected.length] == expected;
}

private int readLeI32(const(ubyte)[] code, size_t offset)
{
    const uint value = cast(uint) code[offset]
        | (cast(uint) code[offset + 1] << 8)
        | (cast(uint) code[offset + 2] << 16)
        | (cast(uint) code[offset + 3] << 24);
    return cast(int) value;
}

/// Derive the address of the pData global variable from the
/// rip-relative load at FlagLoadOffset. The instruction bytes and
/// the following cmpb $0, 0x38(%rax) are verified first, so a
/// different build fails the derivation instead of producing a
/// wrong address.
bool derivePDataGlobalAddress(const(ubyte)[] code, size_t entryAddress,
        out size_t globalAddress)
{
    globalAddress = 0;
    if (!matchBytes(code, FlagLoadOffset,
            cast(const(ubyte)[])[0x48, 0x8B, 0x05]))
        return false;
    if (!matchBytes(code, FlagCmpOffset,
            cast(const(ubyte)[])[0x80, 0x78, 0x38, 0x00]))
        return false;
    const disp = readLeI32(code, FlagLoadOffset + 3);
    globalAddress = cast(size_t)(cast(long) entryAddress
        + cast(long) FlagCmpOffset + cast(long) disp);
    return true;
}

/// Derive SLanguageData::AddKeyValuePair's address from the
/// converting branch's call (E8 rel32 at StoreCallOffset). The
/// flag-clear path's tail jump (E9 rel32 at TailJmpOffset) must
/// resolve to the same target; disagreement fails the derivation.
bool deriveAddKeyValuePairAddress(const(ubyte)[] code, size_t entryAddress,
        out size_t targetAddress)
{
    targetAddress = 0;
    if (code.length < PrefixBytesNeeded)
        return false;
    if (!matchBytes(code, StoreMovOffset,
            cast(const(ubyte)[])[0x45, 0x89, 0xF0]))
        return false;
    if (code[StoreCallOffset] != 0xE8 || code[TailJmpOffset] != 0xE9)
        return false;
    const callTarget = cast(size_t)(cast(long) entryAddress
        + cast(long) StoreCallOffset + 5
        + cast(long) readLeI32(code, StoreCallOffset + 1));
    const jmpTarget = cast(size_t)(cast(long) entryAddress
        + cast(long) TailJmpOffset + 5
        + cast(long) readLeI32(code, TailJmpOffset + 1));
    if (callTarget != jmpTarget)
        return false;
    targetAddress = callTarget;
    return true;
}

unittest
{
    // Decision cases required for the hook: pure ASCII, Japanese
    // only, mixed, unencodable (above BMP), empty.
    auto asciiPlan = planLocalizeStore(cast(const(ubyte)[]) "Back",
        cast(const(ubyte)[]) "Home");
    assert(asciiPlan.action == LocalizePlanAction.delegateToOriginal);
    assert(asciiPlan.reason == LocalizeDelegateReason.asciiValue);

    auto japanesePlan = planLocalizeStore(cast(const(ubyte)[]) "Back",
        cast(const(ubyte)[]) "戻る");
    assert(japanesePlan.action == LocalizePlanAction.storeEscaped);
    assert(japanesePlan.escapedValue
        == cast(ubyte[])[0x11, 0x49, 0x62, 0x10, 0x8B, 0x30]);

    auto mixedPlan = planLocalizeStore(cast(const(ubyte)[]) "CONNECT_TO_IP",
        cast(const(ubyte)[]) "ID接続");
    assert(mixedPlan.action == LocalizePlanAction.storeEscaped);
    assert(mixedPlan.escapedValue == (cast(ubyte[]) "ID")
        ~ cast(ubyte[])[0x10, 0xA5, 0x63, 0x12, 0x9A, 0x74]);

    auto bmpPlan = planLocalizeStore(cast(const(ubyte)[]) "Back",
        cast(const(ubyte)[]) "😀");
    assert(bmpPlan.action == LocalizePlanAction.delegateToOriginal);
    assert(bmpPlan.reason == LocalizeDelegateReason.unencodableValue);

    auto emptyPlan = planLocalizeStore(cast(const(ubyte)[]) "Back",
        cast(const(ubyte)[]) "");
    assert(emptyPlan.action == LocalizePlanAction.delegateToOriginal);
    assert(emptyPlan.reason == LocalizeDelegateReason.asciiValue);

    auto emptyBothPlan = planLocalizeStore(cast(const(ubyte)[]) "",
        cast(const(ubyte)[]) "");
    assert(emptyBothPlan.action == LocalizePlanAction.delegateToOriginal);
    assert(emptyBothPlan.reason == LocalizeDelegateReason.asciiValue);

    // A non-ASCII key delegates even when the value would encode.
    auto keyPlan = planLocalizeStore(cast(const(ubyte)[]) "戻る",
        cast(const(ubyte)[]) "戻る");
    assert(keyPlan.action == LocalizePlanAction.delegateToOriginal);
    assert(keyPlan.reason == LocalizeDelegateReason.nonAsciiKey);

    assert(localizeDelegateReasonText(LocalizeDelegateReason.nonAsciiKey)
        == "non-ascii-key");
    assert(localizeDelegateReasonText(LocalizeDelegateReason.asciiValue)
        == "ascii-value");
    assert(localizeDelegateReasonText(LocalizeDelegateReason.unencodableValue)
        == "unencodable-value");

    // Address derivations, pinned against the real v1.37.5 bytes of
    // LocalizeYmlAddKey (entry 0x23671a1, first 0xE5 bytes; see the
    // details file for the annotated disassembly).
    enum size_t entry = 0x23671a1;
    const(ubyte)[] code = cast(const(ubyte)[]) [
        0x55, 0x41, 0x57, 0x41, 0x56, 0x53, 0x48, 0x83, 0xEC, 0x28,
        0x4C, 0x89, 0xC3, 0x41, 0x89, 0xD6, 0x49, 0x89, 0xF7, 0x48,
        0x89, 0xFD, 0x48, 0x8B, 0x05, 0xD2, 0xF1, 0x0C, 0x01, 0x80,
        0x78, 0x38, 0x00, 0x0F, 0x84, 0x9A, 0x00, 0x00, 0x00, 0x48,
        0x8B, 0x7D, 0x00, 0x48, 0x8D, 0x54, 0x24, 0x08, 0x48, 0xC7,
        0x42, 0x10, 0x00, 0x00, 0x00, 0x00, 0xBE, 0xA0, 0x63, 0x43,
        0x03, 0xE8, 0xBE, 0x66, 0x1E, 0x00, 0x48, 0x8B, 0x44, 0x24,
        0x18, 0x48, 0x85, 0xC0, 0x74, 0x0F, 0x48, 0x8D, 0x7C, 0x24,
        0x08, 0x48, 0x89, 0xFE, 0xBA, 0x03, 0x00, 0x00, 0x00, 0xFF,
        0xD0, 0x49, 0x8B, 0x3F, 0x48, 0x8D, 0x54, 0x24, 0x08, 0x48,
        0x89, 0x2A, 0x48, 0xC7, 0x42, 0x18, 0x20, 0xB2, 0x36, 0x02,
        0x48, 0xC7, 0x42, 0x10, 0x30, 0xB3, 0x36, 0x02, 0xBE, 0xA0,
        0x83, 0x43, 0x03, 0xE8, 0x80, 0x66, 0x1E, 0x00, 0x48, 0x8B,
        0x44, 0x24, 0x18, 0x48, 0x85, 0xC0, 0x74, 0x0F, 0x48, 0x8D,
        0x7C, 0x24, 0x08, 0x48, 0x89, 0xFE, 0xBA, 0x03, 0x00, 0x00,
        0x00, 0xFF, 0xD0, 0x48, 0x8B, 0x7B, 0x10, 0x8B, 0x0B, 0x44,
        0x0F, 0xB6, 0x4B, 0x04, 0xBE, 0xA0, 0x63, 0x43, 0x03, 0xBA,
        0xA0, 0x83, 0x43, 0x03, 0x45, 0x89, 0xF0, 0xE8, 0xA1, 0x45,
        0x00, 0x00, 0x48, 0x83, 0xC4, 0x28, 0x5B, 0x41, 0x5E, 0x41,
        0x5F, 0x5D, 0xC3, 0x48, 0x8B, 0x7B, 0x10, 0x48, 0x8B, 0x75,
        0x00, 0x49, 0x8B, 0x17, 0x8B, 0x0B, 0x44, 0x0F, 0xB6, 0x4B,
        0x04, 0x45, 0x89, 0xF0, 0x48, 0x83, 0xC4, 0x28, 0x5B, 0x41,
        0x5E, 0x41, 0x5F, 0x5D, 0xE9, 0x72, 0x45, 0x00, 0x00,
    ];
    assert(code.length == PrefixBytesNeeded);
    size_t derived;
    assert(derivePDataGlobalAddress(code, entry, derived));
    assert(derived == 0x3436390);
    assert(deriveAddKeyValuePairAddress(code, entry, derived));
    assert(derived == 0x236b7f8);

    // A corrupted opcode byte fails the derivation.
    auto broken = code.dup;
    broken[FlagCmpOffset + 2] = 0x39;
    assert(!derivePDataGlobalAddress(broken, entry, derived));
    broken = code.dup;
    broken[StoreCallOffset] = 0xE9;
    assert(!deriveAddKeyValuePairAddress(broken, entry, derived));
    // A tail jump to a different target fails the derivation.
    broken = code.dup;
    broken[TailJmpOffset + 1] = 0x73;
    assert(!deriveAddKeyValuePairAddress(broken, entry, derived));
    // Truncated input fails both derivations.
    assert(!derivePDataGlobalAddress(code[0 .. 0x10], entry, derived));
    assert(!deriveAddKeyValuePairAddress(code[0 .. 0x10], entry, derived));
}

version (linux)
{
    import core.sys.linux.sys.mman;
    import core.stdc.string : memcpy;
    import std.exception : enforce;
    import std.format : format;
    import std.logger;
    import std.process : environment;
    import plugin.byte_pattern;
    import plugin.constant;
    import plugin.patcher.patcher : makeJmpRel, patch_memory;

    // Complete instructions overwritten at the entry: push rbp,
    // push r15, push r14, push rbx, sub rsp, 0x28 (1+2+2+1+4).
    // The patch is a 5-byte relative jump plus 5 NOPs, the
    // reload_trace form: the entry trampoline is allocated within
    // rel32 range of the target and checked with fitsRel32.
    private enum size_t CopiedLength = 10;
    private enum size_t CallPatchLength = 5;
    private enum int MaxLocalisationBytes = 1 << 20;

    // CUTF8String layout, proven from the game binary's own code
    // (CUTF8String::GetLastLetter and CLetter::Get read exactly
    // these fields; LocalizeYmlAddKey itself passes +0 to the
    // converter): +0 is the data pointer, +8 is the byte length.
    private struct CUTF8StringView
    {
        const(char)* data;
        int length;
    }

    private alias YmlAddKeyFn = extern(C) void function(
        const(void)* key, const(void)* value, int arg3, int arg4, void* ctx);
    private alias AddKeyValuePairFn = extern(C) void function(
        void* languageData, const(char)* key, const(char)* value,
        int intArg, int arg3, bool boolArg);

    private __gshared YmlAddKeyFn localizeOriginal;
    private __gshared AddKeyValuePairFn addKeyValuePairImpl;
    private __gshared size_t pDataGlobalAddress;
    private __gshared bool localizeHookInstalled;
    private __gshared bool localizeHookActive;
    private __gshared bool storeLogged;
    private __gshared bool unreadableLogged;
    private __gshared bool[] delegateReasonLogged;

    private bool fitsRel32(void* fromAddress, void* toAddress)
    {
        auto distance = cast(long) toAddress
            - (cast(long) fromAddress + cast(long) CallPatchLength);
        return distance >= -2147483648L && distance <= 2147483647L;
    }

    private void* makeEntryTrampoline(void* nearAddress, void* callback)
    {
        auto pageSize = 4096UL;
        auto hint = cast(void*)(cast(size_t) nearAddress & ~(pageSize - 1));
        auto memory = mmap(hint, 16, PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
        enforce(memory !is MAP_FAILED,
            "mmap for LocalizeYmlAddKey entry trampoline failed");

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
        enforce(memory !is MAP_FAILED,
            "mmap for LocalizeYmlAddKey original trampoline failed");

        auto code = cast(ubyte*) memory;
        memcpy(code, target, CopiedLength);
        auto resume = cast(size_t) target + CopiedLength;
        code[CopiedLength .. CopiedLength + 10] = [0x48, 0xb8,
            cast(ubyte)(resume >> 0), cast(ubyte)(resume >> 8),
            cast(ubyte)(resume >> 16), cast(ubyte)(resume >> 24),
            cast(ubyte)(resume >> 32), cast(ubyte)(resume >> 40),
            cast(ubyte)(resume >> 48), cast(ubyte)(resume >> 56)];
        code[CopiedLength + 10 .. CopiedLength + 12] = [0xff, 0xe0];
        return memory;
    }

    // The original tests the byte at (*pData) + 0x38 and converts
    // only when it is set. pData is dereferenced on every call,
    // exactly like the original, because the pointer stored in the
    // global is only known at run time.
    private bool conversionFlagSet()
    {
        if (pDataGlobalAddress == 0)
            return false;
        auto pData = *cast(void**) pDataGlobalAddress;
        if (pData is null)
            return false;
        return *(cast(const(ubyte)*) pData + 0x38) != 0;
    }

    private bool readUtf8String(const(void)* stringPtr, out const(ubyte)[] bytes)
    {
        bytes = null;
        if (stringPtr is null)
            return false;
        auto view = cast(const(CUTF8StringView)*) stringPtr;
        if (view.length == 0)
            return true;
        if (view.data is null || view.length < 0
                || view.length > MaxLocalisationBytes)
            return false;
        bytes = cast(const(ubyte)[]) view.data[0 .. view.length];
        return true;
    }

    private void logDelegateReasonOnce(LocalizeDelegateReason reason)
    {
        const idx = cast(size_t) reason;
        if (idx >= delegateReasonLogged.length || delegateReasonLogged[idx])
            return;
        delegateReasonLogged[idx] = true;
        log(LogLevel.info, format(
            "[DIAGNOSTIC] Localize escape hook delegated to original reason=%s",
            localizeDelegateReasonText(reason)));
    }

    private extern(C) void localizeYmlAddKeyCallback(
        const(void)* key, const(void)* value, int arg3, int arg4, void* ctx)
    {
        auto original = localizeOriginal;
        if (localizeHookActive)
        {
            original(key, value, arg3, arg4, ctx);
            return;
        }
        localizeHookActive = true;
        scope (exit)
            localizeHookActive = false;

        // Flag clear: the original stores the raw UTF-8 pair
        // itself; respect its branch and do nothing else.
        if (!conversionFlagSet())
        {
            original(key, value, arg3, arg4, ctx);
            return;
        }

        const(ubyte)[] keyBytes;
        const(ubyte)[] valueBytes;
        if (ctx is null || !readUtf8String(key, keyBytes)
                || !readUtf8String(value, valueBytes))
        {
            if (!unreadableLogged)
            {
                unreadableLogged = true;
                log(LogLevel.info,
                    "[DIAGNOSTIC] Localize escape hook delegated to original reason=unreadable-input");
            }
            original(key, value, arg3, arg4, ctx);
            return;
        }

        auto plan = planLocalizeStore(keyBytes, valueBytes);
        if (plan.action == LocalizePlanAction.delegateToOriginal)
        {
            logDelegateReasonOnce(plan.reason);
            original(key, value, arg3, arg4, ctx);
            return;
        }

        // Store directly, with the argument registers the original's
        // converting branch builds for its 0x2367252 call:
        // rdi = *(ctx + 0x10) (SLanguageData*), ecx = *(int*)ctx,
        // r8d = the entry edx (arg3), r9b = the byte at ctx + 4.
        auto languageData = *cast(void**)(cast(ubyte*) ctx + 0x10);
        const intArg = *cast(const(int)*) ctx;
        const boolArg = *(cast(const(ubyte)*) ctx + 4) != 0;
        auto keyZ = keyBytes.dup ~ cast(ubyte) 0;
        auto valueZ = plan.escapedValue ~ cast(ubyte) 0;
        addKeyValuePairImpl(languageData,
            cast(const(char)*) keyZ.ptr, cast(const(char)*) valueZ.ptr,
            intArg, arg3, boolArg);
        if (!storeLogged)
        {
            storeLogged = true;
            log(LogLevel.info, format(
                "[DIAGNOSTIC] Localize escape hook stored escaped value key=%s value-length=%d escaped-length=%d",
                cast(const(char)[]) keyBytes, valueBytes.length,
                plan.escapedValue.length));
        }
    }

    void initLocalizeEscapeHook(EU4Ver eu4Version)
    {
        if (eu4Version != EU4Ver.v1_37_5)
            return;
        if (environment.get("EU4DLL_LOCALIZE_ESCAPE") != "1")
            return;

        auto pattern = BytePattern.tempInstance();
        pattern.findPattern("55 41 57 41 56 53 48 83 EC 28 4C 89 C3 41 89 D6");
        if (pattern.count() != 1)
        {
            log(LogLevel.error, format(
                "[DIAGNOSTIC] LocalizeYmlAddKey target match count=%s",
                pattern.count()));
            return;
        }
        auto target = cast(void*) pattern.getFirst().address();
        const entryAddress = cast(size_t) target;

        ubyte[PrefixBytesNeeded] prefix;
        memcpy(prefix.ptr, target, prefix.length);
        size_t pDataAddress;
        size_t addKeyAddress;
        if (!derivePDataGlobalAddress(prefix[], entryAddress, pDataAddress)
                || !deriveAddKeyValuePairAddress(prefix[], entryAddress,
                    addKeyAddress))
        {
            log(LogLevel.error,
                "[DIAGNOSTIC] LocalizeYmlAddKey derivation checks failed; hook not installed");
            return;
        }
        pDataGlobalAddress = pDataAddress;
        addKeyValuePairImpl = cast(AddKeyValuePairFn) addKeyAddress;
        localizeOriginal = cast(YmlAddKeyFn) makeOriginalTrampoline(target);
        if (delegateReasonLogged.length == 0)
            delegateReasonLogged = new bool[LocalizeDelegateReason.max + 1];

        if (localizeHookInstalled)
            return;

        auto entry = makeEntryTrampoline(target,
            cast(void*) &localizeYmlAddKeyCallback);
        if (!fitsRel32(target, entry))
        {
            log(LogLevel.error,
                "[DIAGNOSTIC] LocalizeYmlAddKey entry exceeds rel32");
            return;
        }
        patch_memory(target, makeJmpRel(target, entry)
            ~ cast(ubyte[])[0x90, 0x90, 0x90, 0x90, 0x90]);
        localizeHookInstalled = true;
        log(LogLevel.info, format(
            "[DIAGNOSTIC] Localize escape hook installed target=0x%x addKeyValuePair=0x%x pDataGlobal=0x%x",
            entryAddress, addKeyAddress, pDataAddress));
    }
}
else
{
    void initLocalizeEscapeHook(EU4Ver eu4Version) {}
}
