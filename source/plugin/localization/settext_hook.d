module plugin.localization.settext_hook;

import plugin.constant : EU4Ver;

version (linux)
{
    import core.stdc.string : memcpy;
    import core.sys.linux.sys.mman;
    import core.sys.posix.sys.types : ssize_t;
    import core.sys.posix.unistd : getpid, write;
    import std.exception : enforce;
    import std.format : format;
    import std.logger;
    import std.process : environment;
    import std.string : indexOf, lastIndexOf, split;
    import plugin.byte_pattern;
    import plugin.patcher.patcher : patch_memory;

    private enum size_t CopiedLength = 17;
    private enum size_t MaxProbeBytes = 256;
    private enum size_t MaxMappings = 8;

    private enum size_t CStringHeaderBytes = 32;
    private enum size_t SsoCapacity = 15;

    private struct ProbeMapping
    {
        ubyte[MaxProbeBytes] source;
        ubyte[MaxProbeBytes] replacement;
        size_t sourceLength;
        size_t replacementLength;
    }

    private __gshared ProbeMapping[MaxMappings] mappings;
    private __gshared size_t mappingCount;
    private __gshared bool setTextActive;
    private __gshared bool[MaxMappings] replacementLogged;
    private __gshared bool[MaxMappings] contentMismatchLogged;
    private __gshared bool[MaxMappings] capacitySkipLogged;
    private __gshared uint headerSkipLoggedMask;

    private void rawDiagnostic(string message)
    {
        write(2, message.ptr, message.length);
    }

    // process_vm_readv/writev reject unmapped or insufficiently-permitted pages
    // without dereferencing an untrusted CString pointer in this process.
    private extern(C) ssize_t process_vm_readv(int, const void*, size_t, const void*, size_t, ulong);
    private extern(C) ssize_t process_vm_writev(int, const void*, size_t, const void*, size_t, ulong);

    private struct IOVec
    {
        void* base;
        size_t length;
    }

    private bool readMemory(void* address, void[] destination)
    {
        auto local = IOVec(destination.ptr, destination.length);
        auto remote = IOVec(address, destination.length);
        return process_vm_readv(cast(int) getpid(), &local, 1, &remote, 1, 0) == destination.length;
    }

    private bool writeMemory(void* address, const(void)[] source)
    {
        auto local = IOVec(cast(void*) source.ptr, source.length);
        auto remote = IOVec(address, source.length);
        return process_vm_writev(cast(int) getpid(), &local, 1, &remote, 1, 0) == source.length;
    }

    // Kept pure and allocation-free so the format can be tested independently.
    bool parseSetTextProbeEntry(string entry, ref ProbeMapping mapping)
    {
        auto separator = entry.indexOf('=');
        if (separator <= 0 || separator != entry.lastIndexOf('=') || separator + 1 >= entry.length)
            return false;
        auto source = cast(const(ubyte)[]) entry[0 .. separator];
        auto replacement = cast(const(ubyte)[]) entry[separator + 1 .. $];
        if (source.length > MaxProbeBytes || replacement.length > MaxProbeBytes)
            return false;
        mapping.sourceLength = source.length;
        mapping.replacementLength = replacement.length;
        mapping.source[0 .. source.length] = source[];
        mapping.replacement[0 .. replacement.length] = replacement[];
        return true;
    }

    // Capacity of a CString from its 32-byte header (see
    // memory-bank/details/cstring_ownership.md): the data pointer equals
    // object+16 for SSO storage (capacity 15); otherwise +16 holds the
    // heap capacity as a size_t. Pure so it can be unit tested.
    size_t cstringCapacity(const(ubyte)[CStringHeaderBytes] header, size_t objectAddress)
    {
        auto data = *cast(const(size_t)*)(header.ptr);
        if (data == objectAddress + 16)
            return SsoCapacity;
        return *cast(const(size_t)*)(header.ptr + 16);
    }

    bool replacementFitsCapacity(size_t replacementLength, size_t capacity)
    {
        return replacementLength <= capacity;
    }

    // Outcome of comparing one mapping against one observed CString value.
    enum SetTextDecision
    {
        lengthMismatch,
        contentMismatch,
        matched,
    }

    // Pure comparison so the per-mapping decision can be unit tested.
    SetTextDecision decideSetTextMapping(const ref ProbeMapping mapping, const(ubyte)[] value)
    {
        if (mapping.sourceLength != value.length)
            return SetTextDecision.lengthMismatch;
        if (value != mapping.source[0 .. mapping.sourceLength])
            return SetTextDecision.contentMismatch;
        return SetTextDecision.matched;
    }

    // Single log format for every per-mapping outcome. Kept pure so tests
    // pin the fields (mapping id, target length, result, reason) exactly.
    string formatSetTextReplacementLog(long mappingId, size_t targetLength,
            bool applied, string reason)
    {
        return format("[DIAGNOSTIC-RAW] SetText mapping id=%d length=%d result=%s reason=%s\n",
            mappingId, targetLength, applied ? "applied" : "skipped", reason);
    }

    // Why parseSetTextProbeEntry rejected an entry, for the load-time log.
    string probeEntryRejectionReason(string entry)
    {
        auto separator = entry.indexOf('=');
        if (separator < 0)
            return "missing-separator";
        if (separator != entry.lastIndexOf('='))
            return "multiple-separators";
        if (separator == 0)
            return "empty-source";
        if (separator + 1 >= entry.length)
            return "empty-replacement";
        if (separator > MaxProbeBytes || entry.length - separator - 1 > MaxProbeBytes)
            return "too-long";
        return "none";
    }

    private void logHeaderSkip(size_t targetLength, string reason, uint bit)
    {
        if (headerSkipLoggedMask & bit)
            return;
        headerSkipLoggedMask |= bit;
        rawDiagnostic(formatSetTextReplacementLog(-1, targetLength, false, reason));
    }

    private void loadProbeMappings()
    {
        mappingCount = 0;
        auto configured = environment.get("EU4DLL_SETTEXT_REPLACEMENTS");
        if (configured.length == 0)
            return;
        foreach (entryId, entry; configured.split(';'))
        {
            if (mappingCount == MaxMappings)
            {
                log(LogLevel.error, format(
                    "[DIAGNOSTIC] SetText mapping id=%d length=%d result=skipped reason=too-many-mappings",
                    entryId, entry.length));
                break;
            }
            ProbeMapping mapping;
            if (parseSetTextProbeEntry(entry, mapping))
            {
                log(LogLevel.info, format(
                    "[DIAGNOSTIC] SetText mapping id=%d length=%d result=loaded reason=none",
                    mappingCount, mapping.sourceLength));
                mappings[mappingCount++] = mapping;
            }
            else
                log(LogLevel.error, format(
                    "[DIAGNOSTIC] SetText mapping id=%d length=%d result=skipped reason=%s",
                    entryId, entry.length, probeEntryRejectionReason(entry)));
        }
    }

    private bool tryReplace(void* cstring)
    {
        ubyte[CStringHeaderBytes] header;
        if (cstring is null || !readMemory(cstring, header[]))
        {
            logHeaderSkip(0, "null-or-unreadable-cstring", 1u << 0);
            return false;
        }
        auto data = *cast(void**)(header.ptr);
        auto length = *cast(long*)(header.ptr + 8);
        if (data is null)
        {
            logHeaderSkip(0, "null-data-pointer", 1u << 1);
            return false;
        }
        if (length <= 0 || length > MaxProbeBytes)
        {
            logHeaderSkip(0, "invalid-length", 1u << 2);
            return false;
        }
        auto capacity = cstringCapacity(header, cast(size_t) cstring);
        if (capacity < cast(size_t) length)
        {
            logHeaderSkip(cast(size_t) length, "invalid-capacity", 1u << 4);
            return false;
        }

        ubyte[MaxProbeBytes + 1] value;
        if (!readMemory(data, value[0 .. cast(size_t) length + 1]) ||
                value[cast(size_t) length] != 0)
        {
            logHeaderSkip(cast(size_t) length, "value-unreadable-or-missing-nul", 1u << 3);
            return false;
        }
        foreach (i; 0 .. mappingCount)
        {
            auto mapping = &mappings[i];
            // Only same-length values are candidates for this mapping; other
            // lengths are not this mapping's outcome and stay unlogged, so
            // the probe does not flood the log on every SetText call.
            final switch (decideSetTextMapping(*mapping, value[0 .. cast(size_t) length]))
            {
            case SetTextDecision.lengthMismatch:
                continue;
            case SetTextDecision.contentMismatch:
                // Once this mapping has an outcome, a later same-length
                // string is not a new outcome for it.
                if (!contentMismatchLogged[i] && !replacementLogged[i])
                {
                    contentMismatchLogged[i] = true;
                    rawDiagnostic(formatSetTextReplacementLog(i, cast(size_t) length,
                        false, "content-mismatch"));
                }
                continue;
            case SetTextDecision.matched:
                break;
            }
            if (!replacementFitsCapacity(mapping.replacementLength, capacity))
            {
                if (!capacitySkipLogged[i] && !replacementLogged[i])
                {
                    capacitySkipLogged[i] = true;
                    rawDiagnostic(formatSetTextReplacementLog(i, cast(size_t) length,
                        false, "exceeds-capacity"));
                }
                return false;
            }
            // Write replacement bytes plus the terminating NUL, then update
            // the length field (+8) to match; data pointer and +16 stay
            // untouched, as required by cstring_ownership.md.
            ubyte[MaxProbeBytes + 1] replacementValue;
            replacementValue[0 .. mapping.replacementLength] =
                mapping.replacement[0 .. mapping.replacementLength];
            replacementValue[mapping.replacementLength] = 0;
            auto newLength = cast(size_t) mapping.replacementLength;
            auto replaced = writeMemory(data,
                    replacementValue[0 .. mapping.replacementLength + 1])
                && writeMemory(cast(void*)(cast(ubyte*) cstring + 8),
                    (cast(ubyte*) &newLength)[0 .. size_t.sizeof]);
            if (!replacementLogged[i])
            {
                replacementLogged[i] = true;
                // Keep the plain marker as well: eu4_smoke.sh greps for it.
                if (replaced)
                    rawDiagnostic("[DIAGNOSTIC-RAW] SetText replacement applied\n");
                rawDiagnostic(formatSetTextReplacementLog(i, cast(size_t) length,
                    replaced, replaced ? "none" : "write-failed"));
            }
            return replaced;
        }
        return false;
    }

    // Only rdx (the first CString observed in the GDB trace) is interpreted.
    // The entry shim preserves every argument register and the caller's stack,
    // so the unverified trailing ABI is passed to the original unchanged.
    private extern(C) void setTextProbe(void* first)
    {
        if (setTextActive)
            return;
        setTextActive = true;
        scope (exit) setTextActive = false;
        if (mappingCount != 0)
            tryReplace(first);
    }

    private ubyte[] makeAbsoluteJmp(void* destination)
    {
        auto address = cast(size_t) destination;
        return [0xff, 0x25, 0, 0, 0, 0,
            cast(ubyte)(address >> 0), cast(ubyte)(address >> 8),
            cast(ubyte)(address >> 16), cast(ubyte)(address >> 24),
            cast(ubyte)(address >> 32), cast(ubyte)(address >> 40),
            cast(ubyte)(address >> 48), cast(ubyte)(address >> 56)];
    }

    private void* makeTrampoline(void* target)
    {
        auto memory = mmap(null, 32, PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
        enforce(memory !is MAP_FAILED, "mmap for SetText trampoline failed");
        auto code = cast(ubyte*) memory;
        memcpy(code, target, CopiedLength);
        auto resume = cast(size_t) target + CopiedLength;
        code[CopiedLength .. CopiedLength + 10] = [0x48, 0xb8,
            cast(ubyte)(resume >> 0), cast(ubyte)(resume >> 8), cast(ubyte)(resume >> 16),
            cast(ubyte)(resume >> 24), cast(ubyte)(resume >> 32), cast(ubyte)(resume >> 40),
            cast(ubyte)(resume >> 48), cast(ubyte)(resume >> 56)];
        code[CopiedLength + 10 .. CopiedLength + 12] = [0xff, 0xe0];
        return memory;
    }

    private void* makeProbeStub(void* callback, void* original)
    {
        // Save the six integer argument registers, call the bounded probe with
        // rdx as its only argument, restore them, and tail-jump to the original.
        auto code = cast(ubyte*) mmap(null, 64, PROT_READ | PROT_WRITE | PROT_EXEC,
            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        enforce(code !is MAP_FAILED, "mmap for SetText probe failed");
        size_t i;
        code[i++] = 0x57;             // push rdi
        code[i++] = 0x56;             // push rsi
        code[i++] = 0x52;             // push rdx
        code[i++] = 0x51;             // push rcx
        code[i++] = 0x41; code[i++] = 0x50; // push r8
        code[i++] = 0x41; code[i++] = 0x51; // push r9
        code[i++] = 0x48; code[i++] = 0x89; code[i++] = 0xd7; // mov rdi, rdx
        // Six pushes leave RSP misaligned for a SysV call; reserve 8 bytes.
        code[i++] = 0x48; code[i++] = 0x83; code[i++] = 0xec; code[i++] = 0x08; // sub rsp, 8
        code[i++] = 0x48; code[i++] = 0xb8;
        foreach (shift; [0, 8, 16, 24, 32, 40, 48, 56])
            code[i++] = cast(ubyte)(cast(size_t) callback >> shift);
        code[i++] = 0xff; code[i++] = 0xd0; // call rax
        code[i++] = 0x48; code[i++] = 0x83; code[i++] = 0xc4; code[i++] = 0x08; // add rsp, 8
        code[i++] = 0x41; code[i++] = 0x59; // pop r9
        code[i++] = 0x41; code[i++] = 0x58; // pop r8
        code[i++] = 0x59;             // pop rcx
        code[i++] = 0x5a;             // pop rdx
        code[i++] = 0x5e;             // pop rsi
        code[i++] = 0x5f;             // pop rdi
        code[i++] = 0x48; code[i++] = 0xb8;
        foreach (shift; [0, 8, 16, 24, 32, 40, 48, 56])
            code[i++] = cast(ubyte)(cast(size_t) original >> shift);
        code[i++] = 0xff; code[i++] = 0xe0; // jmp rax
        return code;
    }

    void initSetTextHook(EU4Ver eu4Version)
    {
        if (eu4Version != EU4Ver.v1_37_5 || environment.get("EU4DLL_SETTEXT_PROBE") != "1")
            return;
        loadProbeMappings();
        if (mappingCount == 0)
        {
            log(LogLevel.info, "[DIAGNOSTIC] SetText probe disabled: no valid mappings");
            return;
        }
        auto pattern = BytePattern.tempInstance();
        // This is the observed v1.37.5 CTextSprite::SetText prologue. The
        // copied prefix consists only of complete push instructions.
        pattern.findPattern("55 41 57 41 56 41 55 41 54 53 48 81 EC A8 00 00 00 44 89 4C 24 3C");
        if (pattern.count() != 1)
        {
            rawDiagnostic("[DIAGNOSTIC-RAW] SetText target pattern is not unique\n");
            log(LogLevel.error, "[DIAGNOSTIC] SetText target pattern is not unique");
            return;
        }
        auto target = cast(void*) pattern.getFirst().address();
        auto original = makeTrampoline(target);
        auto callback = makeProbeStub(&setTextProbe, original);
        rawDiagnostic(format("[DIAGNOSTIC-RAW] SetText target=0x%x stub=0x%x\n",
            cast(size_t) target, cast(size_t) callback));
        // The AOB covers the six pushes and the complete stack allocation.
        // The 14-byte absolute jump is followed by three NOPs.
        patch_memory(target, makeAbsoluteJmp(callback) ~ cast(ubyte[])[0x90, 0x90, 0x90]);
        rawDiagnostic("[DIAGNOSTIC-RAW] SetText probe installed\n");
        log(LogLevel.info, "[DIAGNOSTIC] SetText probe installed; only observed rdx CString is inspected; trailing ABI remains unverified");
    }

    unittest
    {
        ProbeMapping mapping;
        assert(parseSetTextProbeEntry("Back=Home", mapping));
        assert(mapping.sourceLength == 4 && mapping.replacementLength == 4);
        assert(mapping.source[0] == 'B' && mapping.source[3] == 'k');
        assert(mapping.replacement[0] == 'H' && mapping.replacement[3] == 'e');
        assert(!parseSetTextProbeEntry("Back=Home=Again", mapping));
        assert(parseSetTextProbeEntry("Long=Shorter", mapping));
        assert(mapping.sourceLength == 4 && mapping.replacementLength == 7);
        assert(parseSetTextProbeEntry("Back=Homepage", mapping));
        assert(mapping.sourceLength == 4 && mapping.replacementLength == 8);
        assert(!parseSetTextProbeEntry("=Home", mapping));
        assert(!parseSetTextProbeEntry("Back=", mapping));

        // Capacity: SSO header (data == object+16) is 15; heap header
        // carries the capacity size_t at +16.
        ubyte[CStringHeaderBytes] ssoHeader;
        auto ssoObject = cast(size_t) 0x1000;
        *cast(size_t*)(ssoHeader.ptr) = ssoObject + 16;
        *cast(size_t*)(ssoHeader.ptr + 8) = 4;
        assert(cstringCapacity(ssoHeader, ssoObject) == 15);
        ubyte[CStringHeaderBytes] heapHeader;
        auto heapObject = cast(size_t) 0x2000;
        *cast(size_t*)(heapHeader.ptr) = cast(size_t) 0x9000;
        *cast(size_t*)(heapHeader.ptr + 8) = 20;
        *cast(size_t*)(heapHeader.ptr + 16) = 31;
        assert(cstringCapacity(heapHeader, heapObject) == 31);
        assert(replacementFitsCapacity(8, 15));
        assert(replacementFitsCapacity(15, 15));
        assert(!replacementFitsCapacity(16, 15));
        assert(replacementFitsCapacity(31, 31));
        assert(!replacementFitsCapacity(32, 31));

        // Per-mapping decision: length first, then content.
        assert(decideSetTextMapping(mapping, cast(const(ubyte)[]) "Back")
            == SetTextDecision.matched);
        assert(decideSetTextMapping(mapping, cast(const(ubyte)[]) "Backx")
            == SetTextDecision.lengthMismatch);
        assert(decideSetTextMapping(mapping, cast(const(ubyte)[]) "Bock")
            == SetTextDecision.contentMismatch);

        // Log line carries mapping id, target length, result and reason.
        assert(formatSetTextReplacementLog(1, 13, true, "none") ==
            "[DIAGNOSTIC-RAW] SetText mapping id=1 length=13 result=applied reason=none\n");
        assert(formatSetTextReplacementLog(0, 4, false, "content-mismatch") ==
            "[DIAGNOSTIC-RAW] SetText mapping id=0 length=4 result=skipped reason=content-mismatch\n");
        assert(formatSetTextReplacementLog(-1, 0, false, "invalid-length") ==
            "[DIAGNOSTIC-RAW] SetText mapping id=-1 length=0 result=skipped reason=invalid-length\n");

        // Load-time rejection reasons match parseSetTextProbeEntry.
        assert(probeEntryRejectionReason("BackHome") == "missing-separator");
        assert(probeEntryRejectionReason("Back=Home=Again") == "multiple-separators");
        assert(probeEntryRejectionReason("=Home") == "empty-source");
        assert(probeEntryRejectionReason("Back=") == "empty-replacement");
        assert(probeEntryRejectionReason("Long=Shorter") == "none");
        assert(probeEntryRejectionReason("Back=Homepage") == "none");
        assert(probeEntryRejectionReason("Back=Home") == "none");
    }
}
else
{
    void initSetTextHook(EU4Ver) {}
}
