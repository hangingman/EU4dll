set pagination off
set confirm off
set breakpoint pending on

# SysV x86-64: rdi is the implicit this pointer. For SetText, rdx/rcx
# are the first two explicit CString arguments after CGraphics* in rsi.
break CTextSprite::SetText(CGraphics*, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int>, FontFormatting, bool)
commands
  silent
  set $settext_hits = $settext_hits + 1
  printf "TRACE_ARGS symbol=CTextSprite::SetText tid=%d pc=%p hit=%d cstring1=%p cstring2=%p\n", $_thread, $pc, $settext_hits, $rdx, $rcx
  continue
end

# For CreateTextSprite, rsi/rdx are the first two explicit CString args.
break CGraphics::CreateTextSprite(CString const&, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int> const&, C2dObject*, FontFormatting, bool)
commands
  silent
  set $createsprite_hits = $createsprite_hits + 1
  printf "TRACE_ARGS symbol=CGraphics::CreateTextSprite tid=%d pc=%p hit=%d cstring1=%p cstring2=%p\n", $_thread, $pc, $createsprite_hits, $rsi, $rdx
  continue
end

set $settext_hits = 0
set $createsprite_hits = 0
run
