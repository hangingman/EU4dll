set pagination off
set confirm off
set breakpoint pending on

# Linux x86-64 PoC.  The first CString argument is rdx; its observed layout
# is {data pointer, byte length}.  All memory access is performed by the
# Python helper below after checking the inferior's /proc/<pid>/maps.
# Multiple mappings use EU4DLL_SETTEXT_REPLACEMENTS='Back=Home;Foo=Bar'.
# Entries must contain exactly one '=' and neither side may be empty.
python
import os

import gdb


class SetTextReplacement(gdb.Breakpoint):
    def __init__(self, mapping_id, source, replacement, apply):
        super().__init__(
            "CTextSprite::SetText(CGraphics*, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int>, FontFormatting, bool)",
            internal=True,
        )
        self.mapping_id = mapping_id
        self.source = source
        self.replacement = replacement
        self.apply = apply
        self.hit = 0
        self.replaced = False

    @staticmethod
    def mappings(inferior):
        result = []
        try:
            with open("/proc/%d/maps" % inferior.pid, "r") as maps:
                for line in maps:
                    fields = line.split(None, 2)
                    begin, end = [int(value, 16) for value in fields[0].split("-", 1)]
                    result.append((begin, end, fields[1]))
        except (OSError, ValueError, IndexError):
            return []
        return result

    @staticmethod
    def covered(maps, address, size, permission):
        if address <= 0 or size < 0:
            return False
        end = address + size
        if end < address:
            return False
        for begin, limit, permissions in maps:
            if begin <= address and end <= limit and permission in permissions:
                return True
        return False

    def stop(self):
        self.hit += 1
        inferior = gdb.selected_inferior()
        frame = gdb.newest_frame()
        try:
            cstring = int(frame.read_register("rdx"))
            maps = self.mappings(inferior)
            if not self.covered(maps, cstring, 16, "r"):
                return False
            raw_header = inferior.read_memory(cstring, 16).tobytes()
            data = int.from_bytes(raw_header[0:8], "little")
            length = int.from_bytes(raw_header[8:16], "little", signed=True)
            if length < 0 or length != len(self.source) or length > 4096:
                return False
            if not self.covered(maps, data, length + 1, "r"):
                return False
            value = inferior.read_memory(data, length + 1).tobytes()
            if value[-1:] != b"\0" or value[:-1] != self.source:
                return False
            tid = int(gdb.parse_and_eval("$_thread"))
            gdb.write("SETTEXT_POC mapping=%d before hit=%d tid=%d length=%d\n"
                      % (self.mapping_id, self.hit, tid, length))
            if not self.apply or self.replaced:
                status = "OBSERVATION_ONLY" if not self.apply else "ALREADY_REPLACED"
                gdb.write("SETTEXT_POC mapping=%d after hit=%d tid=%d length=%d status=%s\n"
                          % (self.mapping_id, self.hit, tid, length, status))
                return False
            # Equal byte lengths make capacity and the CString length invariant
            # explicit.  We do not change the CString object or write a NUL.
            if not self.covered(maps, data, length, "w"):
                gdb.write(
                    "SETTEXT_POC mapping=%d after hit=%d tid=%d length=%d status=SKIP_NOT_WRITABLE\n"
                    % (self.mapping_id, self.hit, tid, length)
                )
                return False
            inferior.write_memory(data, self.replacement)
            if inferior.read_memory(data, length).tobytes() != self.replacement:
                gdb.write(
                    "SETTEXT_POC mapping=%d after hit=%d tid=%d length=%d status=SKIP_VERIFY\n"
                    % (self.mapping_id, self.hit, tid, length)
                )
                return False
            self.replaced = True
            gdb.write(
                "SETTEXT_POC mapping=%d after hit=%d tid=%d length=%d status=REPLACED\n"
                % (self.mapping_id, self.hit, tid, length)
            )
        except (gdb.error, OSError, ValueError, OverflowError):
            # Any uncertain read/write leaves the game buffer untouched (or
            # reports no success) and lets the original call proceed.
            return False
        return False


def parse_mapping(mapping_id, text):
    if text.count("=") != 1:
        return None, "must contain exactly one '='"
    source_text, replacement_text = text.split("=", 1)
    if not source_text or not replacement_text:
        return None, "source and replacement must be non-empty"
    try:
        source = source_text.encode("utf-8", "strict")
        replacement = replacement_text.encode("utf-8", "strict")
    except UnicodeError:
        return None, "source and replacement must be valid UTF-8"
    return (mapping_id, source, replacement), None


def configured_mappings():
    # The plural variable takes precedence.  The old pair remains a fallback
    # so existing observation commands continue to be useful.
    if "EU4DLL_SETTEXT_REPLACEMENTS" in os.environ:
        text = os.environ["EU4DLL_SETTEXT_REPLACEMENTS"]
        if not text:
            return [], ["replacement list is empty"]
        entries = text.split(";")
    elif ("EU4DLL_SETTEXT_SOURCE" in os.environ or
          "EU4DLL_SETTEXT_REPLACEMENT" in os.environ):
        entries = [os.environ.get("EU4DLL_SETTEXT_SOURCE", "") + "=" +
                   os.environ.get("EU4DLL_SETTEXT_REPLACEMENT", "")]
    else:
        return [], []

    mappings = []
    errors = []
    for mapping_id, entry in enumerate(entries, 1):
        mapping, error = parse_mapping(mapping_id, entry)
        if error:
            errors.append("mapping=%d %s" % (mapping_id, error))
        else:
            mappings.append(mapping)
    return mappings, errors


apply = os.environ.get("EU4DLL_SETTEXT_APPLY", "") == "1"
mappings, config_errors = configured_mappings()
for error in config_errors:
    gdb.write("SETTEXT_POC config status=INVALID %s\n" % error)

# Equal UTF-8 byte lengths are required because this PoC does not change the
# CString pointer, length, terminator, or allocation capacity.
for mapping_id, source, replacement in mappings:
    if len(source) != len(replacement):
        gdb.write("SETTEXT_POC mapping=%d length=%d replacement_length=%d status=SKIP_LENGTH_MISMATCH\n"
                  % (mapping_id, len(source), len(replacement)))
        continue
    SetTextReplacement(mapping_id, source, replacement, apply)

end
run
