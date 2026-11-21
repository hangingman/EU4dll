# Variable-length SetText replacement: past trials and capacity measurements

This records how far variable-length replacement got in earlier trials,
where it stopped, and the CString capacities measured on the real game
(2026-11-21). It does not change the replacement permission range.

## Past trial 1: GDB multi-string rewrite PoC (commit f25f5a3, 2026-08-23)

- `tools/replace_eu4_settext_string.gdb` / `.sh`: a GDB Python breakpoint
  on `CTextSprite::SetText` that checked the inferior's `/proc/<pid>/maps`
  before reading the first CString (16-byte header: data pointer + length).
- Equal byte lengths were an explicit precondition: the script logged
  `SKIP_LENGTH_MISMATCH` for differing lengths and never changed the
  CString pointer, length field, terminator, or capacity. Its own header
  text states variable-length replacements such as `Back=戻る` are
  skipped.
- One replacement per mapping, writable-buffer check, verify-after-write.
- Where it stopped: real EU4 replacement was unverified at that point, and
  the variable-length question was left open by design, because CString
  ownership, lifetime, and capacity were all unconfirmed.

## Intervening decisions recorded in memory-bank

- 2026-08-22 progress notes: the single-item SetText replacement PoC was
  deferred; key/value correspondence, argument meaning, buffer lifetime,
  ownership, and termination were unconfirmed, and rewriting the original
  CString directly was ruled out.
- Item 3 investigation (commit 4ddeb85, `details/cstring_ownership.md`):
  CString is a 32-byte std::string-compatible layout; capacity lives at
  +16 (SSO capacity 15, otherwise the heap size_t). The hook at that time
  read only 16 header bytes, so capacity could not be judged at runtime.
  Conclusion recorded there: measure capacity first; only a replacement
  whose length fits the capacity may update +8 and the terminating NUL
  together; over-capacity replacement stays unimplemented.

## Current state (commits 2ab5203 and this change)

- 2ab5203 widened the header read to 32 bytes, added `cstringCapacity`,
  and allowed variable-length replacement within capacity
  (`exceeds-capacity` skip otherwise). Note: that commit went beyond the
  staged plan in `cstring_ownership.md` (log capacity first, measure, then
  decide); this record restores the missing measurement step. No further
  widening of the permission range is made here.
- This change only adds a capacity measurement log line
  (`SetText capacity id=<id> length=<len> capacity=<cap>`, once per
  mapping on first match, via the pure `formatSetTextCapacityLog`) and
  this record. Replacement decisions are unchanged.

## Measured capacities (real hardware, 2026-11-21)

Smoke run `runs/20261121-122907` (eu4_smoke.sh, EU4 v1.37.5, Xvfb,
mappings `Back=Home;Connect to ID=Connect to JP`, EU4 ended by the Exit
button, eu4_wait=0):

| mapping id | source | length | capacity | storage |
|---|---|---|---|---|
| 0 | Back | 4 | 15 | SSO |
| 1 | Connect to ID | 13 | 15 | SSO |

- Both target strings are SSO strings with capacity 15, so a replacement
  of up to 15 bytes fits these two targets; anything longer is skipped
  with `exceeds-capacity` under the current implementation.
- This is a measurement for these two strings in the main-menu flow only.
  Capacities of other strings, and heap-backed strings, are unmeasured.
