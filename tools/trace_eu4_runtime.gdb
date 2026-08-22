set pagination off
set confirm off
set breakpoint pending on

# Observe only the two statically selected text-generation candidates.
break CTextSprite::SetText(CGraphics*, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int>, FontFormatting, bool)
commands
  silent
  printf "TRACE symbol=CTextSprite::SetText tid=%d pc=%p\n", $_thread, $pc
  continue
end

break CGraphics::CreateTextSprite(CString const&, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int> const&, C2dObject*, FontFormatting, bool)
commands
  silent
  printf "TRACE symbol=CGraphics::CreateTextSprite tid=%d pc=%p\n", $_thread, $pc
  continue
end

run
