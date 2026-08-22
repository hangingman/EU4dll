set pagination off
set confirm off
set breakpoint pending on

# Observe only the first ten hits for each function.  The CString object
# layout is observed statically: +0 is the data pointer and +8 is the length.
break CTextSprite::SetText(CGraphics*, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int>, FontFormatting, bool)
commands
  silent
  set $settext_preview_hits = $settext_preview_hits + 1
  if $settext_preview_hits <= 10
    if $rdx != 0
      set $settext_data = *(void **) $rdx
      set $settext_length = *(long long *) ($rdx + 8)
      printf "TRACE_PREVIEW symbol=CTextSprite::SetText tid=%d pc=%p hit=%d cstring=%p data=%p length=%lld\n", $_thread, $pc, $settext_preview_hits, $rdx, $settext_data, $settext_length
    end
  end
  continue
end

break CGraphics::CreateTextSprite(CString const&, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int> const&, C2dObject*, FontFormatting, bool)
commands
  silent
  set $createsprite_preview_hits = $createsprite_preview_hits + 1
  if $createsprite_preview_hits <= 10
    if $rsi != 0
      set $createsprite_data = *(void **) $rsi
      set $createsprite_length = *(long long *) ($rsi + 8)
      printf "TRACE_PREVIEW symbol=CGraphics::CreateTextSprite tid=%d pc=%p hit=%d cstring=%p data=%p length=%lld\n", $_thread, $pc, $createsprite_preview_hits, $rsi, $createsprite_data, $createsprite_length
    end
  end
  continue
end

set $settext_preview_hits = 0
set $createsprite_preview_hits = 0
run
